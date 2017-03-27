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

public final class LaserDistanceRenderer {
    
    let pipeline: MTLRenderPipelineState
    
    let laserDistanceMesh: LaserDistanceMesh
    
    struct VertexUniforms {
        
        var projectionMatrix: float4x4
        
        var angleStart: Float
        var angleIncrement: Float
    }
    
    struct FragmentUniforms {
        
        let minimumDistance = Laser.minimumDistance
        let distanceAccuracy = Laser.distanceAccuracy
    }
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "laserDistanceVertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "laserDistanceFragment")
        
        self.pipeline = try! library.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        self.laserDistanceMesh = LaserDistanceMesh(device: library.device, sampleCount: Laser.sampleCount)
    }
    
    func draw(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        var vertexUniforms = VertexUniforms(projectionMatrix: projectionMatrix,
                                            angleStart: Laser.angleStart,
                                            angleIncrement: Laser.angleIncrement)
        
        var fragmentUniforms = FragmentUniforms()
        
        commandEncoder.setRenderPipelineState(pipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(laserDistanceMesh.vertexBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout.stride(ofValue: vertexUniforms), at: 1)
        
        commandEncoder.setFragmentBytes(&fragmentUniforms, length: MemoryLayout.stride(ofValue: fragmentUniforms), at: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: laserDistanceMesh.indexCount, indexType: .uint16, indexBuffer: laserDistanceMesh.indexBuffer, indexBufferOffset: 0)
    }
    
    // Distances in millimeters
    public func updateMesh(with distances: [UInt16]) {
        
        guard distances.count == laserDistanceMesh.sampleCount else {
            print("Unexpected number of distances: \(distances.count)")
            return
        }
        
        let metersPerMillimeter: Float = 0.001
        
        let convertedDistances = distances.map { Float($0) * metersPerMillimeter }
        
        laserDistanceMesh.store(distances: convertedDistances)
    }
}
