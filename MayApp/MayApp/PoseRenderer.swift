//
//  PoseRenderer.swift
//  MayApp
//
//  Created by Russell Ladd on 4/9/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

public final class PoseRenderer {
    
    let poseBuffer: TypedMetalBuffer<Pose>
    
    public var pose: Pose {
        get {
            return poseBuffer[0]
        }
        set(newPose) {
            poseBuffer[0] = newPose
        }
    }
    
    let mesh: IsoscelesTriangleMesh
    
    let pipeline: MTLRenderPipelineState
    
    let scaleMatrix = float4x4(diagonal: float4(0.01, 0.0075, 1.0, 1.0))
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        poseBuffer = TypedMetalBuffer(device: library.device)
        
        mesh = IsoscelesTriangleMesh(device: library.device)
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "particleVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "colorFragment")
        
        pipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        reset()
    }
    
    struct RenderUniforms {
        
        var modelMatrix: float4x4
        var projectionMatrix: float4x4
        var mapScaleMatrix: float4x4
        var color: float4
    }
    
    func renderPose(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        var uniforms = ParticleRenderUniforms(modelMatrix: scaleMatrix.cmatrix, viewProjectionMatrix: projectionMatrix.cmatrix, mapScaleMatrix: Map.textureScaleMatrix.cmatrix, color: float4(1.0, 0.0, 0.0, 1.0))
        
        commandEncoder.setRenderPipelineState(pipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(poseBuffer.metalBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        commandEncoder.setVertexBuffer(mesh.vertexBuffer, offset: 0, at: 2)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: IsoscelesTriangleMesh.indexCount, indexType: IsoscelesTriangleMesh.indexType, indexBuffer: mesh.indexBuffer, indexBufferOffset: 0, instanceCount: 1)
    }
    
    func reset() {
        
        pose = Pose()
    }
}
