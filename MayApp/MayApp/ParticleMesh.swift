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
    static let vertexCount = 7
    static let indexCount = 9

    init(device: MTLDevice) {
        
        vertexBuffer = device.makeBuffer(length: 7 * MemoryLayout<Vertex>.stride, options: [])
        indexBuffer = device.makeBuffer(length: 9 * MemoryLayout<UInt16>.stride, options: [])
        
        // Draw a lovely tiny arrow points to the positive x-axis
        
        // NOTE: The vertex positions are in a normalized unit [-1.0, 1.0]
        vertexBuffer.contents().storeBytes(of: Vertex(x: 0.0, y: 0.02), toByteOffset: 0 * MemoryLayout<Vertex>.stride, as: Vertex.self)
        vertexBuffer.contents().storeBytes(of: Vertex(x: 0.0, y: -0.02), toByteOffset: 1 * MemoryLayout<Vertex>.stride, as: Vertex.self)
        vertexBuffer.contents().storeBytes(of: Vertex(x: 0.03, y: 0.0), toByteOffset: 2 * MemoryLayout<Vertex>.stride, as: Vertex.self)
        vertexBuffer.contents().storeBytes(of: Vertex(x: 0.0, y: 0.002), toByteOffset: 3 * MemoryLayout<Vertex>.stride, as: Vertex.self)
        vertexBuffer.contents().storeBytes(of: Vertex(x: -0.015, y: 0.002), toByteOffset: 4 * MemoryLayout<Vertex>.stride, as: Vertex.self)
        vertexBuffer.contents().storeBytes(of: Vertex(x: 0.0, y: -0.002), toByteOffset: 5 * MemoryLayout<Vertex>.stride, as: Vertex.self)
        vertexBuffer.contents().storeBytes(of: Vertex(x: -0.015, y: -0.002), toByteOffset: 6 * MemoryLayout<Vertex>.stride, as: Vertex.self)
        
        indexBuffer.contents().storeBytes(of: 0, toByteOffset: 0 * MemoryLayout<UInt16>.stride, as: UInt16.self)
        indexBuffer.contents().storeBytes(of: 1, toByteOffset: 1 * MemoryLayout<UInt16>.stride, as: UInt16.self)
        indexBuffer.contents().storeBytes(of: 2, toByteOffset: 2 * MemoryLayout<UInt16>.stride, as: UInt16.self)
        indexBuffer.contents().storeBytes(of: 3, toByteOffset: 3 * MemoryLayout<UInt16>.stride, as: UInt16.self)
        indexBuffer.contents().storeBytes(of: 4, toByteOffset: 4 * MemoryLayout<UInt16>.stride, as: UInt16.self)
        indexBuffer.contents().storeBytes(of: 5, toByteOffset: 5 * MemoryLayout<UInt16>.stride, as: UInt16.self)
        indexBuffer.contents().storeBytes(of: 5, toByteOffset: 6 * MemoryLayout<UInt16>.stride, as: UInt16.self)
        indexBuffer.contents().storeBytes(of: 4, toByteOffset: 7 * MemoryLayout<UInt16>.stride, as: UInt16.self)
        indexBuffer.contents().storeBytes(of: 6, toByteOffset: 8 * MemoryLayout<UInt16>.stride, as: UInt16.self)
    }
}
