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
    
    var headVertex : float2 = float2(0.0, 0.0)
    public var headAngle: Float = 0.0 {
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
        
        self.headBuffer = library.device.makeBuffer(length: 3 * MemoryLayout<float2>.size, options: [])
    }
    
    func updateHeadBuffer() {
        
        let leftAngle = headAngle + Float(M_PI) - Float(M_PI / 12.0)
        let rightAngle = headAngle + Float(M_PI) + Float(M_PI / 12.0)
        
        let headTriangleVertices = [
            headVertex,
            headVertex + 0.05 * float2(cos(leftAngle), sin(leftAngle)),
            headVertex + 0.05 * float2(cos(rightAngle), sin(rightAngle))
        ]
        
        headTriangleVertices.withUnsafeBytes { body in
            headBuffer.contents().copyBytes(from: body.baseAddress!, count: body.count)
        }
    }
    
    func draw(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        // use this uniform to make the latest position in the center
        let transformMatrix = float4x4(angle: -headAngle) * float4x4(translation: float3(-headVertex.x, -headVertex.y, 0.0))
        var uniforms = Uniforms(projectionMatrix: projectionMatrix * transformMatrix)
        // use this to keep the original position in the center
        //var uniforms = Uniforms(projectionMatrix: projectionMatrix)
        
        commandEncoder.setRenderPipelineState(pipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(odometryMesh.vertexBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, at: 1)
        
        commandEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: odometryMesh.sampleCount)
        
        commandEncoder.setRenderPipelineState(pipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(headBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, at: 1)
        
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
    
    public func updateMesh(with position: float4) {
        
        odometryMesh.append(sample: OdometryMesh.Vertex(x: position.x, y: position.y))
        headVertex = float2(position.x, position.y)
    }
    
    public func resetMesh() {
        
        odometryMesh.sampleCount = 0
    }
}
