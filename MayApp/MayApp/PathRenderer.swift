//
//  PathRenderer.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/04/04.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

public final class PathRenderer {
    
    let pfMap: PFMap
    
//    let pathPipelineState: MTLRenderPipelineState
    let pathRenderPipeline: MTLRenderPipelineState
    
    let commandQueue: MTLCommandQueue
    
    let squareMesh: SquareMesh
    
    struct RenderUniforms {
        var projectionMatrix: float4x4
    }
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue) {
        
        // Path map texture
        self.pfMap = PFMap(library: library, pixelFormat: pixelFormat, commandQueue: commandQueue)
        
        // Render Pipeline
//        let pathPipelineDescriptor = MTLRenderPipelineDescriptor()
//        pathPipelineDescriptor.colorAttachments[0].pixelFormat = PFMap.pixelFormat
//        pathPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
//        pathPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
//        pathPipelineDescriptor.vertexFunction = library.makeFunction(name: "pathUpdateVertex")!
//        pathPipelineDescriptor.fragmentFunction = library.makeFunction(name: "pathUpdateFramgnet")!
//        
//        pathPipelineState = try! library.device.makeRenderPipelineState(descriptor: pathPipelineDescriptor)
        
        // Square Mesh
        squareMesh = SquareMesh(device: library.device)
        
        // Make Uniforms
        // TODO
        
        // Render Pipeline
        let pathRenderDescriptor = MTLRenderPipelineDescriptor()
        pathRenderDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pathRenderDescriptor.vertexFunction = library.makeFunction(name: "mapVertex")
        pathRenderDescriptor.fragmentFunction = library.makeFunction(name: "mapFragment")
        
        pathRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: pathRenderDescriptor)
        
        // Store Command Queue
        self.commandQueue = commandQueue
        
    }
    
    func drawMap(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        var uniforms = RenderUniforms(projectionMatrix: projectionMatrix)
        
        commandEncoder.setRenderPipelineState(pathRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(squareMesh.vertexBuffer, offset: 0, at:0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        commandEncoder.setFragmentTexture(pfMap.pfmapTexture, at:0)
        
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: squareMesh.vertexCount)
    }
    
    func drawPath(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
    }
    
}
