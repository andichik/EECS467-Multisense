//
//  PathMapRenderer.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/04/19.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

final class PathMapRenderer {
    // Current Laser Maximum distane is 30m, with 0.03m accuracy.
    // Texture Dimension of roughly 1000 should be sufficient
    
    static let texels = 1024
    static let meters: Float = 15.0
    static let texelsPerMeter = Float(texels) / meters
    
    static var textureScaleMatrix = float4x4(diagonal: float4(2.0 / meters, 2.0 / meters, 1.0, 1.0))
    
    static let pixelFormat = MTLPixelFormat.r16Snorm
    
    static let textureDescriptor: MTLTextureDescriptor = {
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: texels, height: texels, mipmapped: false)
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return textureDescriptor
    }()
    
    let texture: MTLTexture
    let mapUpdatePiplineState: MTLRenderPipelineState
    let mapRenderPipeline: MTLRenderPipelineState
    
    let obstacleThickness: Float = 0.1 // meters
    let updateAmount: Float = 1
    
    struct MapUpdateVertexUniforms {
        
        // Moves vertices from origin to robot's pose
        // Scales from meters to texels
        var projectionMatrix: float4x4
        
        var angleStart: Float
        var angleIncrement: Float
        
        var obstacleThickness: Float // meters
    }
    
    struct MapUpdateFragmentUniforms {
        
        var minimumDistance: Float   // meters
        var maximumDistance: Float   // meters
        var obstacleThickness: Float // meters
        
        var updateAmount: Float
    }
    
    var mapUpdateVertexUniforms: MapUpdateVertexUniforms
    var mapUpdateFragmentUniforms: MapUpdateFragmentUniforms
    
    let squareMesh: SquareMesh
    
//    let poseMatrix = float4x4(translation: float4(-Float(texels) * 0.5 / texelsPerMeter,0.0, 0.0, 1.0)) * float4x4(angle: 0.0)
    let poseMatrix = float4x4(translation: float4(0.0, 0.0, 0.0, 1.0)) * float4x4(angle: 0.0)

    
    // To help reset map
    let commandQueue: MTLCommandQueue
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue) {
        
        // Make Path Map Texture
        texture = library.device.makeTexture(descriptor: PathMapRenderer.textureDescriptor)
        texture.label = "Path Map Texture"
        
        // Map Update Pipeline
        let mapUpdatePipelineDescriptor = MTLRenderPipelineDescriptor()
        mapUpdatePipelineDescriptor.colorAttachments[0].pixelFormat = PathMapRenderer.pixelFormat
        mapUpdatePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        mapUpdatePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        mapUpdatePipelineDescriptor.vertexFunction = library.makeFunction(name: "mapUpdateVertex")
        mapUpdatePipelineDescriptor.fragmentFunction = library.makeFunction(name: "mapUpdateFragment")
        
        mapUpdatePiplineState = try! library.device.makeRenderPipelineState(descriptor: mapUpdatePipelineDescriptor)
        
        // Make uniforms
        
        
        mapUpdateVertexUniforms = MapUpdateVertexUniforms(projectionMatrix: PathMapRenderer.textureScaleMatrix * poseMatrix,
                                                          angleStart: Laser.angleStart,
                                                          angleIncrement: Laser.angleIncrement,
                                                          obstacleThickness: obstacleThickness)
        mapUpdateFragmentUniforms = MapUpdateFragmentUniforms(minimumDistance: Laser.minimumDistance, maximumDistance: Laser.maximumDistance, obstacleThickness: obstacleThickness, updateAmount: 0.1)
        
        // Square Mesh (for 'draw')
        squareMesh = SquareMesh(device: library.device)
        
        // Map Render Pipeline
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "mapVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "mapFragment")
        
        mapRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        // Store command queue
        self.commandQueue = commandQueue
    }
    
    func updateMap(commandBuffer: MTLCommandBuffer, laserDistanceMesh: LaserDistanceMesh) {
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
        
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder.label = "Update Path Map"
        
        commandEncoder.setRenderPipelineState(mapUpdatePiplineState)
        commandEncoder.setVertexBuffer(laserDistanceMesh.vertexBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&mapUpdateVertexUniforms, length: MemoryLayout.stride(ofValue: mapUpdateVertexUniforms), at: 1)
        
        commandEncoder.setFragmentBytes(&mapUpdateFragmentUniforms, length: MemoryLayout.stride(ofValue: mapUpdateFragmentUniforms), at: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: laserDistanceMesh.indexCount, indexType: LaserDistanceMesh.indexType, indexBuffer: laserDistanceMesh.indexBuffer, indexBufferOffset: 0)
        
        commandEncoder.endEncoding()
    }
    
    struct RenderUniforms {
        
        var projectionMatrix: float4x4
    }
    
    func renderMap(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        var uniforms = RenderUniforms(projectionMatrix: projectionMatrix)
        
        commandEncoder.setRenderPipelineState(mapRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(squareMesh.vertexBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        commandEncoder.setFragmentTexture(texture, at: 0)
        
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: squareMesh.vertexCount)
    }
}
