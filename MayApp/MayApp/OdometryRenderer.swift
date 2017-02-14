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
    }
    
    func draw(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        //TODO: make the latest postition in the center
        var uniforms = Uniforms(projectionMatrix: projectionMatrix)
        
        commandEncoder.setRenderPipelineState(pipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(odometryMesh.vertexBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, at: 1)
        
        commandEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: odometryMesh.sampleCount)
    }
    
    public func updateMesh(with position: float4) {
        
        odometryMesh.append(sample: OdometryMesh.Vertex(x: position.x, y: position.y))
    }
}
