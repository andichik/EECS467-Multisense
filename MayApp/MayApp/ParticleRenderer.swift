//
//  ParticleRenderer.swift
//  MayApp
//
//  Created by Yulin Xie on 2/18/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

public final class ParticleRenderer {
    
    static let particles = 2000
    
    // Error range for updating particles with odometry readings
    let rotationErrorFromRotation: Float = 0.5       // constant
    let rotationErrorFromTranslation: Float = 0.5    // radians/meter
    let translationErrorFromRotation: Float = 0.2    // meters/radian
    let translationErrorFromTranslation: Float = 0.1 // constant

    var particleBufferRing: Ring<MTLBuffer>         // Pose
    let weightBuffer: MTLBuffer                     // Float
    let indexPoolBuffer: MTLBuffer                  // UInt32
    
    private(set) var bestPoseIndex = 0
    
    var bestPose: Pose {
        return particleBufferRing.current.contents().load(fromByteOffset: MemoryLayout<Pose>.stride * bestPoseIndex, as: Pose.self)
    }
    
    let particleUpdatePipeline: MTLComputePipelineState
    let weightUpdatePipeline: MTLComputePipelineState
    let samplingPipeline: MTLComputePipelineState
    
    struct ParticleUpdateUniforms {
        
        var numOfParticles: UInt32
        
        var randSeedR1: UInt32
        var randSeedT: UInt32
        var randSeedR2: UInt32
        
        var rotationErrorFromRotation: Float
        var rotationErrorFromTranslation: Float
        var translationErrorFromRotation: Float
        var translationErrorFromTranslation: Float
        
        var odometryUpdates: Odometry.Delta
    }
    
    struct WeightUpdateUniforms {
        
        let numberOfParticles: UInt16
        let laserDistancesCount: UInt16
        let testIncrement: UInt16
        
        let mapTexelsPerMeter: Float        // texels per meter
        let mapSize: Float                  // meters
        
        let laserAngleStart: Float          // radians
        let laserAngleIncrement: Float      // radians
        
        let minimumLaserDistance: Float     // meters
        let maximumLaserDistance: Float     // meters
        
        let occupancyThreshold: Float
        
        let scanThreshold: Float            // meters
    }
    
    struct SamplingUniforms {
        
        var numOfParticles: UInt32
        
        var randSeed: UInt32
    }
    
    var particleUpdateUniforms: ParticleUpdateUniforms
    var weightUpdateUniforms: WeightUpdateUniforms
    var samplingUniforms: SamplingUniforms
    
    let particleRenderPipeline: MTLRenderPipelineState
    
    let particleRenderScaleMatrix = float4x4(diagonal: float4(0.02, 0.015, 1.0, 1.0))
    
    struct RenderUniforms {
        
        var modelMatrix: float4x4
        var projectionMatrix: float4x4
        var mapScaleMatrix: float4x4
        var color: float4
    }
    
    let particleMesh: IsoscelesTriangleMesh
    
    let commandQueue: MTLCommandQueue
    
    let resetParticlesPipeline: MTLComputePipelineState
    
    let threadsPerThreadGroup: MTLSize
    let threadgroupsPerGrid: MTLSize

    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue) {
        
        // Make particle and weight buffers
        
        particleBufferRing = Ring(repeating: { index in
            
            let buffer = library.device.makeBuffer(length: ParticleRenderer.particles * MemoryLayout<Pose>.stride, options: [])
            buffer.label = "Particle Buffer \(index)"
            return buffer
            
        }, count: 2)
        
        weightBuffer = library.device.makeBuffer(length: ParticleRenderer.particles * MemoryLayout<Float>.stride, options: [])
        
        // Make index pool buffer for importance sampling
        
        indexPoolBuffer = library.device.makeBuffer(length: ParticleRenderer.particles * MemoryLayout<UInt32>.stride, options: [])
        
        // Make compute pipelines
        
        let particleUpdateFunction = library.makeFunction(name: "updateParticles")!
        let weightUpdateFunction = library.makeFunction(name: "updateWeights")!
        let samplingFunction = library.makeFunction(name: "sampling")!
        
        particleUpdatePipeline = try! library.device.makeComputePipelineState(function: particleUpdateFunction)
        weightUpdatePipeline = try! library.device.makeComputePipelineState(function: weightUpdateFunction)
        samplingPipeline = try! library.device.makeComputePipelineState(function: samplingFunction)
        
        // Make uniforms
        
        let testIncrement = 10
        let numberOfTests = (Laser.sampleCount - 1) / testIncrement + 1 // 109
        
        particleUpdateUniforms = ParticleUpdateUniforms(numOfParticles: UInt32(ParticleRenderer.particles),
                                                        randSeedR1: 0,
                                                        randSeedT: 0,
                                                        randSeedR2: 0,
                                                        rotationErrorFromRotation: rotationErrorFromRotation,
                                                        rotationErrorFromTranslation: rotationErrorFromTranslation,
                                                        translationErrorFromRotation: translationErrorFromRotation,
                                                        translationErrorFromTranslation: translationErrorFromTranslation,
                                                        odometryUpdates: Odometry.Delta())
        
        weightUpdateUniforms = WeightUpdateUniforms(numberOfParticles: UInt16(ParticleRenderer.particles),
                                                    laserDistancesCount: UInt16(Laser.sampleCount),
                                                    testIncrement: UInt16(testIncrement),
                                                    mapTexelsPerMeter: Map.texelsPerMeter,
                                                    mapSize: Map.meters,
                                                    laserAngleStart: Laser.angleStart,
                                                    laserAngleIncrement: Laser.angleWidth / Float(numberOfTests - 1),
                                                    minimumLaserDistance: Laser.minimumDistance,
                                                    maximumLaserDistance: Laser.maximumDistance,
                                                    occupancyThreshold: 0.0, scanThreshold: 20.0)
        
        samplingUniforms = SamplingUniforms(numOfParticles: UInt32(ParticleRenderer.particles), randSeed: 0)
        
        // Make particle render pipeline
        
        particleMesh = IsoscelesTriangleMesh(device: library.device)
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "particleVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "colorFragment")
        
        particleRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        // Store the command queue
        self.commandQueue = commandQueue
        
        // Make the reset particles pipeline
        let resetParticlesFunction = library.makeFunction(name: "resetParticles")!
        resetParticlesPipeline = try! library.device.makeComputePipelineState(function: resetParticlesFunction)
        
        // Make thread execution sizes
        let threadgroupWidth = particleUpdatePipeline.maxTotalThreadsPerThreadgroup
        threadsPerThreadGroup = MTLSize(width: threadgroupWidth, height: 1, depth: 1)
        
        threadgroupsPerGrid = MTLSize(width: (ParticleRenderer.particles + threadgroupWidth - 1) / threadgroupWidth, height: 1, depth: 1)
        
        // Initialize particles
        
        resetParticles()
    }
    
    func moveAndWeighParticles(commandBuffer: MTLCommandBuffer, odometryDelta: Odometry.Delta, mapTexture: MTLTexture, laserDistancesBuffer: MTLBuffer, completionHandler: @escaping (_ bestPose: Pose) -> Void) {
        
        particleUpdateUniforms.odometryUpdates = odometryDelta
        
        // Move particles 
        let particleUpdateCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        particleUpdateCommandEncoder.label = "Move Particles"
        
        particleUpdateUniforms.randSeedR1 = arc4random()
        particleUpdateUniforms.randSeedT = arc4random()
        particleUpdateUniforms.randSeedR2 = arc4random()
        
        particleUpdateCommandEncoder.setComputePipelineState(particleUpdatePipeline)
        particleUpdateCommandEncoder.setBuffer(particleBufferRing.current, offset: 0, at: 0)
        particleUpdateCommandEncoder.setBuffer(particleBufferRing.next, offset: 0, at: 1)
        particleUpdateCommandEncoder.setBytes(&particleUpdateUniforms, length: MemoryLayout.stride(ofValue: particleUpdateUniforms), at: 2)
        
        particleUpdateCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        particleUpdateCommandEncoder.endEncoding()
        
        // Calculate weights
        let weightUpdateCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        weightUpdateCommandEncoder.label = "Calculate Weights"
        
        weightUpdateCommandEncoder.setComputePipelineState(weightUpdatePipeline)
        
        // Using "next" because the particleRing is not rotated yet
        weightUpdateCommandEncoder.setBuffer(particleBufferRing.next, offset: 0, at: 0)
        weightUpdateCommandEncoder.setBuffer(weightBuffer, offset: 0, at: 1)
        weightUpdateCommandEncoder.setBuffer(laserDistancesBuffer, offset: 0, at: 2)
        weightUpdateCommandEncoder.setTexture(mapTexture, at: 0)
        weightUpdateCommandEncoder.setBytes(&weightUpdateUniforms, length: MemoryLayout.stride(ofValue: weightUpdateUniforms), at: 3)
        
        weightUpdateCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        weightUpdateCommandEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in
            DispatchQueue.main.async {
                
                var bestPoseIndex = 0
                
                var highestWeight = -Float.infinity
                for i in 0..<ParticleRenderer.particles {
                    
                    let weight = self.weightBuffer.contents().load(fromByteOffset: MemoryLayout<Float>.stride * i, as: Float.self)
                    if (weight > highestWeight) {
                        highestWeight = weight
                        bestPoseIndex = i
                    }
                }
                
                self.bestPoseIndex = bestPoseIndex
                
                completionHandler(self.bestPose)
            }
        }
    }
    
    func resampleParticles(commandBuffer: MTLCommandBuffer) {
        
        // Re-sampling
        samplingUniforms.randSeed = arc4random()
        
        // find the best pose and largest weight & normalize the weights
        var highestWeight = -Float.infinity
        for i in 0..<ParticleRenderer.particles {
            
            let weight = weightBuffer.contents().load(fromByteOffset: MemoryLayout<Float>.stride * i, as: Float.self)
            if (weight > highestWeight) {
                highestWeight = weight
            }
        }
        
        var sumWeights: Float = 0.0
        for i in 0..<ParticleRenderer.particles {
            
            let weight = weightBuffer.contents().load(fromByteOffset: MemoryLayout<Float>.stride * i, as: Float.self)
            // the exponent of the shifted weight should be in [0, 1]
            sumWeights += pow(exp(weight - highestWeight), 0.1)
        }
        
        // update index pool
        var poolSize = 0
        for i in 0..<ParticleRenderer.particles {
            
            // The number of index items to put into the pool = normalized weight * the size of the pool
            let weight = weightBuffer.contents().load(fromByteOffset: MemoryLayout<Float>.stride * i, as: Float.self)
            let normalizedWeight = pow(exp(weight - highestWeight), 0.1) / sumWeights
            let num = UInt32((normalizedWeight * Float(ParticleRenderer.particles)).rounded())
            
            for _ in 0..<num {
                // Check if the pool is filled up
                if poolSize >= ParticleRenderer.particles {
                    continue
                }
                indexPoolBuffer.contents().storeBytes(of: UInt32(i), toByteOffset: MemoryLayout<UInt32>.stride * poolSize, as: UInt32.self)
                poolSize += 1
            }
        }
        
        let samplingCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        
        samplingCommandEncoder.setComputePipelineState(samplingPipeline)
        samplingCommandEncoder.setBuffer(particleBufferRing.current, offset: 0, at: 0)
        samplingCommandEncoder.setBuffer(particleBufferRing.next, offset: 0, at: 1)
        samplingCommandEncoder.setBuffer(indexPoolBuffer, offset: 0, at: 2)
        samplingCommandEncoder.setBytes(&samplingUniforms, length: MemoryLayout.stride(ofValue: samplingUniforms), at: 3)
        
        samplingCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        samplingCommandEncoder.endEncoding()
    }
    
    func renderParticles(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        var uniforms = RenderUniforms(modelMatrix: particleRenderScaleMatrix, projectionMatrix: projectionMatrix, mapScaleMatrix: Map.textureScaleMatrix, color: float4(1.0, 1.0, 0.0, 1.0))
        
        commandEncoder.setRenderPipelineState(particleRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(particleBufferRing.current, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        commandEncoder.setVertexBuffer(particleMesh.vertexBuffer, offset: 0, at: 2)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: IsoscelesTriangleMesh.indexCount, indexType: IsoscelesTriangleMesh.indexType, indexBuffer: particleMesh.indexBuffer, indexBufferOffset: 0, instanceCount: ParticleRenderer.particles)
        
        uniforms.color = float4(1.0, 0.0, 0.0, 1.0)
        
        commandEncoder.setVertexBufferOffset(bestPoseIndex * MemoryLayout<Pose>.stride, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: IsoscelesTriangleMesh.indexCount, indexType: IsoscelesTriangleMesh.indexType, indexBuffer: particleMesh.indexBuffer, indexBufferOffset: 0)
    }
    
    func resetParticles() {
        
        // reset the particle buffer
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        let computeCommand = commandBuffer.makeComputeCommandEncoder()
        
        computeCommand.setComputePipelineState(resetParticlesPipeline)
        
        var sizeOfParticleBuffer = UInt32(ParticleRenderer.particles)
        
        computeCommand.setBuffer(particleBufferRing.current, offset: 0, at: 0)
        computeCommand.setBuffer(weightBuffer, offset: 0, at: 1)
        computeCommand.setBytes(&sizeOfParticleBuffer, length: MemoryLayout.stride(ofValue: sizeOfParticleBuffer), at: 2)

        let threadgroupWidth = resetParticlesPipeline.maxTotalThreadsPerThreadgroup
        let threadsPerThreadGroup = MTLSize(width: threadgroupWidth, height: 1, depth: 1)
        
        let threadgroupsPerGrid = MTLSize(width: (ParticleRenderer.particles + threadgroupWidth - 1) / threadgroupWidth, height: 1, depth: 1)
        
        computeCommand.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        computeCommand.endEncoding()
        
        commandBuffer.commit()
    }
}
