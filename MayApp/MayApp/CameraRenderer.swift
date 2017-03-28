//
//  CameraRenderer.swift
//  MayApp
//
//  Created by Yanqi Liu on 3/23/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

public final class CameraRenderer {
    
    let camera: Camera
    
    struct CameraUpdateVertexUniforms {
        var projectionMatrix: float4x4
    }

    var cameraUpdateVertexUniforms: CameraUpdateVertexUniforms
    
    let squareMesh: SquareMesh
    
    let cameraRenderPipeline: MTLRenderPipelineState
    
    let commandQueue: MTLCommandQueue
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue){
        
        // Make camera
        camera = Camera(device: library.device)
        
        // Make uniforms
        cameraUpdateVertexUniforms = CameraUpdateVertexUniforms(projectionMatrix: float4x4())
        
        // Make square mesh
        squareMesh = SquareMesh (device: library.device)
        
        // Make camera render pipeline
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "cameraVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "cameraFragment")
        
        cameraRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        self.commandQueue = commandQueue
    }
    
    public func updateCameraTexture(with colorbuffer: [Camera.RGBA]) {
        
        // Copy color_buffer into texture
        colorbuffer.withUnsafeBytes { body in
            //Bytes per row should be width for 2D textures
            camera.texture.replace(region: MTLRegionMake2D(0, 0, Camera.width, Camera.height), mipmapLevel: 0, withBytes: body.baseAddress!, bytesPerRow: Camera.width * MemoryLayout<Camera.RGBA>.stride)
        }
    }
    
    struct RenderUniforms {
        
        var projectionMatrix: float4x4
    }
    
    func renderCamera(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4){
        
        var uniforms = RenderUniforms(projectionMatrix: projectionMatrix)
        
        commandEncoder.setRenderPipelineState(cameraRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(squareMesh.vertexBuffer, offset:0, at:0)
        commandEncoder.setVertexBytes(&uniforms, length:MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        commandEncoder.setFragmentTexture(camera.texture, at: 0)
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: squareMesh.vertexCount)
    }
}
