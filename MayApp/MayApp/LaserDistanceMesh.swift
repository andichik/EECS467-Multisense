//
//  LaserDistanceMesh.swift
//  MayApp
//
//  Created by Russell Ladd on 2/4/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

final class LaserDistanceMesh {
    
    let sampleCount: Int
    let indexCount: Int
    
    let triangleCount: Int
    
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    
    struct Vertex {
        let distance: Float // meters
    }
    
    typealias Index = UInt16
    
    static let indexType = MTLIndexType.uint16
    
    init(device: MTLDevice, sampleCount: Int) {
        
        // Buffer format: sampleCount vertices, 1 zero vertex
        // Don't need to set zero vertex because it is implicitly zero
        
        let vertexCount = sampleCount + 1
        self.triangleCount = sampleCount - 1
        
        self.sampleCount = sampleCount
        self.indexCount = 3 * triangleCount
        
        self.vertexBuffer = device.makeBuffer(length: vertexCount * MemoryLayout<Vertex>.stride, options: [])
        self.indexBuffer = device.makeBuffer(length: indexCount * MemoryLayout<Index>.stride, options: [])
        
        for i in 0..<triangleCount {
            
            self.indexBuffer.contents().storeBytes(of: Index(sampleCount), toByteOffset: (3 * i + 0) * MemoryLayout<Index>.stride, as: Index.self)
            self.indexBuffer.contents().storeBytes(of: Index(i),           toByteOffset: (3 * i + 1) * MemoryLayout<Index>.stride, as: Index.self)
            self.indexBuffer.contents().storeBytes(of: Index(i + 1),       toByteOffset: (3 * i + 2) * MemoryLayout<Index>.stride, as: Index.self)
        }
    }
    
    // distances in meters
    func store(distances: [Float]) {
        
        precondition(distances.count == sampleCount)
        
        distances.withUnsafeBytes { body in
            vertexBuffer.contents().copyBytes(from: body.baseAddress!, count: body.count)
        }
    }
}
