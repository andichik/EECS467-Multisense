//
//  OdometryRenderer.swift
//  MayApp
//
//  Created by Yulin Xie on 2/13/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

public final class OdometryRenderer {
    
    let pipeline: MTLRenderPipelineState
    
    let odometryMesh: OdometryMesh
    
    var headPose = Pose() {
        didSet {
            updateHeadBuffer()
        }
    }
    
    let headBuffer: MTLBuffer
    
    struct Uniforms {
        
        var projectionMatrix: float4x4
    }
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "odometryVertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "colorFragment")
        
        self.pipeline = try! library.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        self.odometryMesh = OdometryMesh(device: library.device)
        
        self.headBuffer = library.device.makeBuffer(length: 3 * MemoryLayout<float2>.stride, options: [])
    }
    
    func updateHeadBuffer() {
        
        let leftAngle = headPose.angle + Float(M_PI) - Float(M_PI / 12.0)
        let rightAngle = headPose.angle + Float(M_PI) + Float(M_PI / 12.0)
        
        let headTriangleVertices = [
            headPose.position,
            headPose.position + 0.05 * float4(cos(leftAngle), sin(leftAngle), 0.0, 0.0),
            headPose.position + 0.05 * float4(cos(rightAngle), sin(rightAngle), 0.0, 0.0)
        ]
        
        headTriangleVertices.withUnsafeBytes { body in
            headBuffer.contents().copyBytes(from: body.baseAddress!, count: body.count)
        }
    }
    
    func draw(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        // use this uniform to make the latest position in the center
        let transformMatrix = float4x4(angle: -headPose.angle) * float4x4(translation: float3(-headPose.position.x, -headPose.position.y, 0.0))
        var uniforms = Uniforms(projectionMatrix: projectionMatrix * transformMatrix)
        
        // use this to keep the original position in the center
        //var uniforms = Uniforms(projectionMatrix: projectionMatrix)
        
        commandEncoder.setRenderPipelineState(pipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(odometryMesh.vertexBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        commandEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: odometryMesh.sampleCount)
        
        commandEncoder.setVertexBuffer(headBuffer, offset: 0, at: 0)
        
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
    
    public func updateMeshAndHead(with pose: Pose) {
        
        odometryMesh.append(sample: OdometryMesh.Vertex(position: pose.position))
        
        headPose = pose
    }
    
    public func resetMesh() {
        
        odometryMesh.sampleCount = 0
    }
}
