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
    
    // Maximum texture size on A9 GPU is 16384, but A7 and A8 is only 8192
    // Mac supports 16384
    let mapTexels = 8192
    let mapMeters: Float = 4.0
    let mapTexelsPerMeter: Float
    
    let minimumLaserDistance: Float = 0.1   // meters
    let laserDistanceAccuracy: Float = 0.03 // meters = 30mm
    
    let mapTextureRing: Ring<MTLTexture>
    
    let mapUpdatePipeline: MTLComputePipelineState
    
    let laserDistancesTexture: MTLTexture
    
    struct Uniforms {
        
        var robotPosition: float4           // meters
        var robotAngle: Float               // radians
        
        var mapTexelsPerMeter: Float        // texels per meter
        
        var laserAngleStart: Float          // radians
        var laserAngleWidth: Float          // radians
        
        var minimumLaserDistance: Float     // meters
        var laserDistanceAccuracy: Float    // meters
        
        var dOccupancy: Float
    }
    
    var uniforms: Uniforms
    
    let squareMesh: SquareMesh
    
    let mapRenderPipeline: MTLRenderPipelineState
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        // Calculate metrics
        
        mapTexelsPerMeter = Float(mapTexels) / mapMeters
        
        // Make map textures
        
        // Texture values will be in [0.0, 1.0] where 0.0 is free and 1.0 is occupied
        let mapTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Snorm, width: mapTexels, height: mapTexels, mipmapped: false)
        
        let mapTextures = (0..<2).map { _ in library.device.makeTexture(descriptor: mapTextureDescriptor) }
        
        mapTextureRing = Ring(mapTextures)
        
        // Make laser distance texture
        
        let laserDistancesTextureDescriptor = MTLTextureDescriptor()
        laserDistancesTextureDescriptor.textureType = .type1D
        laserDistancesTextureDescriptor.pixelFormat = .r16Uint
        laserDistancesTextureDescriptor.width = 1081
        
        laserDistancesTexture = library.device.makeTexture(descriptor: laserDistancesTextureDescriptor)
        
        // Make pipeline
        
        let mapUpdateFunction = library.makeFunction(name: "updateMap")!
        
        mapUpdatePipeline = try! library.device.makeComputePipelineState(function: mapUpdateFunction)
        
        // Make uniforms
        
        uniforms = Uniforms(robotPosition: float4(0.0, 0.0, 0.0, 1.0),
                            robotAngle: 0.0,
                            mapTexelsPerMeter: mapTexelsPerMeter,
                            laserAngleStart: Float(M_PI) * -0.75,
                            laserAngleWidth: Float(M_PI) *  1.50,
                            minimumLaserDistance: minimumLaserDistance,
                            laserDistanceAccuracy: laserDistanceAccuracy,
                            dOccupancy: 0.2)
        
        // Make square mesh
        
        squareMesh = SquareMesh(device: library.device)
        
        // Make map render pipeline
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "mapVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "mapFragment")
        
        mapRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }
    
    func updateMap(from pose: Pose, commandBuffer: MTLCommandBuffer) {
        
        uniforms.robotPosition = pose.position
        uniforms.robotAngle = pose.angle
        
        let computeCommand = commandBuffer.makeComputeCommandEncoder()
        
        computeCommand.setComputePipelineState(mapUpdatePipeline)
        
        computeCommand.setTexture(mapTextureRing.current, at: 0)
        computeCommand.setTexture(mapTextureRing.next, at: 1)
        computeCommand.setTexture(laserDistancesTexture, at: 2)
        computeCommand.setBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 0)
        
        let threadgroupWidth = mapUpdatePipeline.threadExecutionWidth
        let threadgroupHeight = mapUpdatePipeline.maxTotalThreadsPerThreadgroup / threadgroupWidth
        
        let threadsPerThreadGroup = MTLSize(width: threadgroupWidth, height: threadgroupHeight, depth: 1)
        
        let threadgroupsPerGrid = MTLSize(width: (mapTexels + threadgroupWidth - 1) / threadgroupWidth,
                                          height: (mapTexels + threadgroupHeight - 1) / threadgroupHeight,
                                          depth: 1)
        
        computeCommand.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        computeCommand.endEncoding()
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
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.size(ofValue: uniforms), at: 1)
        
        commandEncoder.setFragmentTexture(mapTextureRing.next, at: 0)
        
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: squareMesh.vertexCount)
    }
    
    func updateLaserDistancesTexture(with distances: [Int]) {
        
        guard distances.count == laserDistancesTexture.width else {
            print("Unexpected number of laser distances: \(distances.count)")
            return
        }
        
        let unsignedDistances = distances.map { UInt16($0) }
        
        // Copy distances into texture
        unsignedDistances.withUnsafeBytes { body in
            // Bytes per row should be 0 for 1D textures
            laserDistancesTexture.replace(region: MTLRegionMake1D(0, distances.count), mipmapLevel: 0, withBytes: body.baseAddress!, bytesPerRow: 0)
        }
    }
}
