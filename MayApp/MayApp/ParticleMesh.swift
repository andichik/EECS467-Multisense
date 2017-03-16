//
//  ParticleMesh.swift
//  MayApp
//
//  Created by Yulin Xie on 3/6/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

final class ParticleMesh {
    
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    
    struct Vertex {
        let position: float4
        
        init(x: Float, y: Float) {
            
            position = float4(x, y, 0.0, 1.0)
        }
    }
    
    static let particleIndexType = MTLIndexType.uint16
    static let vertexCount = 3
    static let indexCount = 3

    init(device: MTLDevice) {
        
        vertexBuffer = device.makeBuffer(length: ParticleMesh.vertexCount * MemoryLayout<Vertex>.stride, options: [])
        indexBuffer = device.makeBuffer(length: ParticleMesh.indexCount * MemoryLayout<UInt16>.stride, options: [])
        
        vertexBuffer.contents().storeBytes(of: Vertex(x: -1.0, y:  0.6), toByteOffset: 0 * MemoryLayout<Vertex>.stride, as: Vertex.self)
        vertexBuffer.contents().storeBytes(of: Vertex(x: -1.0, y: -0.6), toByteOffset: 1 * MemoryLayout<Vertex>.stride, as: Vertex.self)
        vertexBuffer.contents().storeBytes(of: Vertex(x:  1.0, y:  0.0), toByteOffset: 2 * MemoryLayout<Vertex>.stride, as: Vertex.self)
        
        indexBuffer.contents().storeBytes(of: 0, toByteOffset: 0 * MemoryLayout<UInt16>.stride, as: UInt16.self)
        indexBuffer.contents().storeBytes(of: 1, toByteOffset: 1 * MemoryLayout<UInt16>.stride, as: UInt16.self)
        indexBuffer.contents().storeBytes(of: 2, toByteOffset: 2 * MemoryLayout<UInt16>.stride, as: UInt16.self)
    }
}
