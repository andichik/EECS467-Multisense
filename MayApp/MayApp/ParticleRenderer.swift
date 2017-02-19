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
    let mapTexels = 8192
    let mapMeters: Float = 4.0
    let mapTexelsPerMeter: Float
    
    let minimumLaserDistance: Float = 0.1   // meters

    
    var particleBufferRing: Ring<MTLBuffer>
    let weightBuffer: MTLBuffer
    
    let particleUpdatePipeline: MTLComputePipelineState
    let weightUpdatePipeline: MTLComputePipelineState
    let samplingPipeline: MTLComputePipelineState
    
    struct ParticleUpdateUniforms {
        
        var randSeed: Float                 // TODO: probably adding more seeds
        
        var odometryUpdates: Odometry.OdometryUpdates
    }
    
    struct WeightUpdateUniforms {
        
        var mapTexelsPerMeter: Float        // texels per meter
        
        var laserAngleStart: Float          // radians
        var laserAngleWidth: Float          // radians
        
        var minimumLaserDistance: Float     // meters
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
    

    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        // Calculate metrics
        
        mapTexelsPerMeter = Float(mapTexels) / mapMeters
        
        // Make particle and weight buffers
        
        let particleBuffers = (0..<2).map { _ in library.device.makeBuffer(length: ParticleRenderer.particles * MemoryLayout<Pose>.size, options: [])}
        particleBufferRing = Ring(particleBuffers)
        
        weightBuffer = library.device.makeBuffer(length: ParticleRenderer.particles * MemoryLayout<Float>.size, options: [])
        
        // Make compute pipelines
        
        let particleUpdateFunction = library.makeFunction(name: "updateParticles")!
        let weightUpdateFunction = library.makeFunction(name: "updateWeights")!
        let samplingFunction = library.makeFunction(name: "sampling")!
        
        particleUpdatePipeline = try! library.device.makeComputePipelineState(function: particleUpdateFunction)
        weightUpdatePipeline = try! library.device.makeComputePipelineState(function: weightUpdateFunction)
        samplingPipeline = try! library.device.makeComputePipelineState(function: samplingFunction)
        
        // Make uniforms
        
        particleUpdateUniforms = ParticleUpdateUniforms(randSeed: 0.0, odometryUpdates: Odometry.OdometryUpdates(dx: 0.0, dy: 0.0, dAngle: 0.0))
        weightUpdateUniforms = WeightUpdateUniforms(mapTexelsPerMeter: mapTexelsPerMeter, laserAngleStart: Float(M_PI) * -0.75, laserAngleWidth: Float(M_PI) *  1.50, minimumLaserDistance: minimumLaserDistance)
        samplingUniforms = SamplingUniforms(randSeed: 0.0)
        
        // Make map render pipeline
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "odometryVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "colorFragment")
        
        particleRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }
    
    func updateParticles() {
        //TODO
    }
    
    func renderParticles(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        //TODO
    }

}
