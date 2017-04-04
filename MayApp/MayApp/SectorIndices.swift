//
//  SectorIndices.swift
//  MayApp
//
//  Created by Russell Ladd on 4/2/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal

final class SectorIndices {
    
    let outerVertexCount: Int
    let indexCount: Int
    
    let triangleCount: Int
    
    let indexBuffer: MTLBuffer
    
    typealias Index = UInt16
    
    static let indexType = MTLIndexType.uint16
    
    init(device: MTLDevice, outerVertexCount: Int) {
        
        self.triangleCount = outerVertexCount - 1
        
        self.outerVertexCount = outerVertexCount
        self.indexCount = 3 * triangleCount
        
        self.indexBuffer = device.makeBuffer(length: indexCount * MemoryLayout<Index>.stride, options: [])
        
        for i in 0..<triangleCount {
            
            self.indexBuffer.contents().storeBytes(of: Index(outerVertexCount), toByteOffset: (3 * i + 0) * MemoryLayout<Index>.stride, as: Index.self)
            self.indexBuffer.contents().storeBytes(of: Index(i),           toByteOffset: (3 * i + 1) * MemoryLayout<Index>.stride, as: Index.self)
            self.indexBuffer.contents().storeBytes(of: Index(i + 1),       toByteOffset: (3 * i + 2) * MemoryLayout<Index>.stride, as: Index.self)
        }
    }
}
