//
//  LaserDistanceRenderer.swift
//  MayApp
//
//  Created by Russell Ladd on 2/5/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

final class LaserDistanceRenderer {
    
    let pipeline: MTLRenderPipelineState
    
    let laserDistanceMesh: LaserDistanceMesh
    
    let uniformBuffer: MTLBuffer
    
    struct Uniforms {
        
        var projectionMatrix: float4x4
    }
    
    var uniforms = Uniforms(projectionMatrix: float4x4(1.0))
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, mesh: LaserDistanceMesh) {
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "laserDistanceVertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "laserDistanceFragment")
        
        self.pipeline = try! library.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        self.laserDistanceMesh = mesh
        
        self.uniformBuffer = library.device.makeBuffer(length: MemoryLayout<Uniforms>.size, options: [])
    }
    
    func draw(with commandEncoder: MTLRenderCommandEncoder) {
        
        commandEncoder.setRenderPipelineState(pipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(laserDistanceMesh.vertexBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, at: 1)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: laserDistanceMesh.indexCount, indexType: .uint16, indexBuffer: laserDistanceMesh.indexBuffer, indexBufferOffset: 0)
    }
}
