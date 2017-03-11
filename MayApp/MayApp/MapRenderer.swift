//
//  MapRenderer.swift
//  MayApp
//
//  Created by Russell Ladd on 2/15/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

public final class MapRenderer {
    
    let map: Map
    
    let mapUpdatePipelineState: MTLRenderPipelineState
        
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
    
    let mapRenderPipeline: MTLRenderPipelineState
    
    // To help reset map
    let commandQueue: MTLCommandQueue
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue) {
        
        // Make map textures
        
        map = Map(device: library.device)
        
        // Make map update pipeline
        
        let mapUpdatePipelineDescriptor = MTLRenderPipelineDescriptor()
        mapUpdatePipelineDescriptor.colorAttachments[0].pixelFormat = Map.pixelFormat
        mapUpdatePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        mapUpdatePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        mapUpdatePipelineDescriptor.vertexFunction = library.makeFunction(name: "mapUpdateVertex")!
        mapUpdatePipelineDescriptor.fragmentFunction = library.makeFunction(name: "mapUpdateFragment")!
        
        mapUpdatePipelineState = try! library.device.makeRenderPipelineState(descriptor: mapUpdatePipelineDescriptor)
        
        // Make uniforms
        
        let obstacleThickness: Float = 0.1 // meters
        
        mapUpdateVertexUniforms = MapUpdateVertexUniforms(projectionMatrix: float4x4(),
                                                          angleStart: Laser.angleStart,
                                                          angleIncrement: Laser.angleIncrement,
                                                          obstacleThickness: obstacleThickness)
        
        mapUpdateFragmentUniforms = MapUpdateFragmentUniforms(minimumDistance: Laser.minimumDistance,
                                                              maximumDistance: Laser.maximumDistance,
                                                              obstacleThickness: obstacleThickness,
                                                              updateAmount: 0.1)
        
        // Make square mesh
        
        squareMesh = SquareMesh(device: library.device)
        
        // Make map render pipeline
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "mapVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "mapFragment")
        
        mapRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        // Store command queue
        self.commandQueue = commandQueue
    }
    
    func updateMap(commandBuffer: MTLCommandBuffer, pose: Pose, laserDistanceMesh: LaserDistanceMesh) {
        
        mapUpdateVertexUniforms.projectionMatrix = Map.textureScaleMatrix * pose.matrix
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = map.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        commandEncoder.label = "Update Map"
        
        commandEncoder.setRenderPipelineState(mapUpdatePipelineState)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
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
        
        commandEncoder.setFragmentTexture(map.texture, at: 0)
        
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: squareMesh.vertexCount)
    }
    
    public func reset() {
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        let resetPassDescriptor = MTLRenderPassDescriptor()
        resetPassDescriptor.colorAttachments[0].texture = map.texture
        resetPassDescriptor.colorAttachments[0].loadAction = .clear
        resetPassDescriptor.colorAttachments[0].storeAction = .store
        
        let resetMapEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: resetPassDescriptor)
        
        resetMapEncoder.endEncoding()
        
        commandBuffer.commit()
    }
}
