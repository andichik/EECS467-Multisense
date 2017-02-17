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
    
    struct Uniforms {
        
        var projectionMatrix: float4x4
    }
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "laserDistanceVertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "colorFragment")
        
        self.pipeline = try! library.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        self.laserDistanceMesh = LaserDistanceMesh(device: library.device, sampleCount: 1081)
    }
    
    func draw(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        var uniforms = Uniforms(projectionMatrix: projectionMatrix)
        
        commandEncoder.setRenderPipelineState(pipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(laserDistanceMesh.vertexBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, at: 1)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: laserDistanceMesh.indexCount, indexType: .uint16, indexBuffer: laserDistanceMesh.indexBuffer, indexBufferOffset: 0)
    }
    
    // Distances in millimeters
    public func updateMesh(with distances: [Int]) {
        
        guard distances.count == laserDistanceMesh.sampleCount else {
            print("Unexpected number of distances: \(distances.count)")
            return
        }
        
        let angleStart = Float(M_PI) * -0.75
        let angleWidth = Float(M_PI) *  1.50
        
        let angleIncrement = angleWidth / Float(distances.count)
        
        let metersPerMillimeter: Float = 0.001
        
        let samples = distances.enumerated().map { i, distance in
            return LaserDistanceMesh.Sample(angle: angleStart + Float(i) * angleIncrement,
                                            distance: Float(distance) * metersPerMillimeter)
        }
        
        laserDistanceMesh.store(samples: samples)
    }
}
