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
    let rotationErrorRange: Float = 1.0            // radius
    let translationErrorRange: Float = 0.5         // meters

    var particleBufferRing: Ring<MTLBuffer>         // Pose
    let weightBuffer: MTLBuffer                     // Float
    let indexPoolBuffer: MTLBuffer                  // UInt32
    
    let particleUpdatePipeline: MTLComputePipelineState
    let weightUpdatePipeline: MTLComputePipelineState
    let samplingPipeline: MTLComputePipelineState
    
    struct ParticleUpdateUniforms {
        
        var numOfParticles: UInt32
        
        var randSeedR: UInt32
        var randSeedT: UInt32
        
        var errRangeR: Float
        var errRangeT: Float
        
        var odometryUpdates: Odometry.Delta
    }
    
    struct WeightUpdateUniforms {
        
        let numOfParticles: UInt32
        let numOfTests: UInt32
        
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
    
    struct RenderUniforms {
        
        var projectionMatrix: float4x4
    }
    
    let commandQueue: MTLCommandQueue
    
    let resetParticlesPipeline: MTLComputePipelineState

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
        
        let weightUpdateNumOfTests: UInt32 = 100
        
        particleUpdateUniforms = ParticleUpdateUniforms(numOfParticles: UInt32(ParticleRenderer.particles), randSeedR: 0, randSeedT: 0, errRangeR: rotationErrorRange, errRangeT: translationErrorRange,  odometryUpdates: Odometry.Delta())
        weightUpdateUniforms = WeightUpdateUniforms(numOfParticles: UInt32(ParticleRenderer.particles), numOfTests: weightUpdateNumOfTests, mapTexelsPerMeter: Map.texelsPerMeter, mapSize: Map.meters, laserAngleStart: Laser.angleStart, laserAngleIncrement: Laser.angleWidth / Float(weightUpdateNumOfTests - 1), minimumLaserDistance: Laser.minimumDistance, maximumLaserDistance: Laser.maximumDistance, occupancyThreshold: 0.0, scanThreshold: 10.0)
        samplingUniforms = SamplingUniforms(numOfParticles: UInt32(ParticleRenderer.particles), randSeed: 0)
        
        // Make map render pipeline
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "particleVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "colorFragment")
        
        particleRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        // Store the command queue
        self.commandQueue = commandQueue
        
        // Make the reset particles pipeline
        let resetParticlesFunction = library.makeFunction(name: "resetParticles")!
        resetParticlesPipeline = try! library.device.makeComputePipelineState(function: resetParticlesFunction)
    }
    
    func updateParticles(commandBuffer: MTLCommandBuffer, mapTexture: MTLTexture, laserDistancesTexture: MTLTexture) {
        
        // Calculate thread execution sizes
        let threadgroupWidth = particleUpdatePipeline.maxTotalThreadsPerThreadgroup
        let threadsPerThreadGroup = MTLSize(width: threadgroupWidth, height: 1, depth: 1)
        
        let threadgroupsPerGrid = MTLSize(width: (ParticleRenderer.particles + threadgroupWidth - 1) / threadgroupWidth, height: 1, depth: 1)
        
        // Move particles 
        let particleUpdateCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        particleUpdateCommandEncoder.label = "Move Particles"
        
        particleUpdateUniforms.randSeedR = arc4random()
        particleUpdateUniforms.randSeedT = arc4random()
        
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
        weightUpdateCommandEncoder.setBuffer(particleBufferRing.next, offset: 0, at: 0)
        weightUpdateCommandEncoder.setBuffer(weightBuffer, offset: 0, at: 1)
        weightUpdateCommandEncoder.setTexture(mapTexture, at: 0)
        weightUpdateCommandEncoder.setTexture(laserDistancesTexture, at: 1)
        weightUpdateCommandEncoder.setBytes(&weightUpdateUniforms, length: MemoryLayout.stride(ofValue: weightUpdateUniforms), at: 2)
        
        weightUpdateCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        weightUpdateCommandEncoder.endEncoding()
    }
    
    func resampleParticles(commandBuffer: MTLCommandBuffer) {
        
        // FIXME: Store these in a common place
        let threadgroupWidth = particleUpdatePipeline.maxTotalThreadsPerThreadgroup
        let threadsPerThreadGroup = MTLSize(width: threadgroupWidth, height: 1, depth: 1)
        
        let threadgroupsPerGrid = MTLSize(width: (ParticleRenderer.particles + threadgroupWidth - 1) / threadgroupWidth, height: 1, depth: 1)
        
        // Re-sampling
        let samplingCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        
        samplingUniforms.randSeed = arc4random()
        
        // sum up the unnormalized weights
        var sumWeights: Float = 0.0
        for i in 0..<ParticleRenderer.particles {
            
            sumWeights += weightBuffer.contents().load(fromByteOffset: MemoryLayout<Float>.stride * i, as: Float.self)
        }
        
        // update index pool
        var poolSize = 0
        for i in 0..<ParticleRenderer.particles {
            
            // The number of index items to put into the pool = normalized weight * the size of the pool
            let normalizedWeight = weightBuffer.contents().load(fromByteOffset: MemoryLayout<Float>.stride * i, as: Float.self) / sumWeights
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
        
        samplingCommandEncoder.setComputePipelineState(samplingPipeline)
        samplingCommandEncoder.setBuffer(particleBufferRing.current, offset: 0, at: 0)
        samplingCommandEncoder.setBuffer(particleBufferRing.next, offset: 0, at: 1)
        samplingCommandEncoder.setBuffer(indexPoolBuffer, offset: 0, at: 2)
        samplingCommandEncoder.setBytes(&samplingUniforms, length: MemoryLayout.stride(ofValue: samplingUniforms), at: 3)
        
        samplingCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        samplingCommandEncoder.endEncoding()
    }
    
    func renderParticles(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        var uniforms = RenderUniforms(projectionMatrix: projectionMatrix)
        
        commandEncoder.setRenderPipelineState(particleRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(particleBufferRing.current, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        commandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: ParticleRenderer.particles)
    }
    
    func resetParticles() {
        
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

    public func updateOdometry(with odometryUpdates: Odometry.Delta) {
        
        particleUpdateUniforms.odometryUpdates = odometryUpdates
    }
}
