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

    var particleBufferRing: Ring<MTLBuffer>
    let weightBuffer: MTLBuffer
    
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
        
        var randSeed: Float
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
        
        let particleBuffers = (0..<2).map { _ in library.device.makeBuffer(length: ParticleRenderer.particles * MemoryLayout<Pose>.stride, options: [])}
        particleBufferRing = Ring(particleBuffers)
        
        weightBuffer = library.device.makeBuffer(length: ParticleRenderer.particles * MemoryLayout<Float>.stride, options: [])
        
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
        samplingUniforms = SamplingUniforms(randSeed: 0.0)
        
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
    
    func updateParticles(commandBuffer: MTLCommandBuffer) {
        //TODO
        
        // Move particles 
        let particleUpdateCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        
        particleUpdateUniforms.randSeedR = arc4random()
        particleUpdateUniforms.randSeedT = arc4random()
        
        particleUpdateCommandEncoder.setComputePipelineState(particleUpdatePipeline)
        particleUpdateCommandEncoder.setBuffer(particleBufferRing.current, offset: 0, at: 0)
        particleUpdateCommandEncoder.setBuffer(particleBufferRing.next, offset: 0, at: 1)
        particleUpdateCommandEncoder.setBytes(&particleUpdateUniforms, length: MemoryLayout.stride(ofValue: particleUpdateUniforms), at: 2)
        
        let threadgroupWidth = particleUpdatePipeline.maxTotalThreadsPerThreadgroup
        let threadsPerThreadGroup = MTLSize(width: threadgroupWidth, height: 1, depth: 1)
        
        let threadgroupsPerGrid = MTLSize(width: (ParticleRenderer.particles + threadgroupWidth - 1) / threadgroupWidth, height: 1, depth: 1)
        
        particleUpdateCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        particleUpdateCommandEncoder.endEncoding()
        
        // Calculate weights
        
        // Re-sampling
        
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
        computeCommand.setBytes(&sizeOfParticleBuffer, length: MemoryLayout.stride(ofValue: sizeOfParticleBuffer), at: 1)

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
