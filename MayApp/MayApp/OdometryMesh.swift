//
//  OdometryMesh.swift
//  MayApp
//
//  Created by Yulin Xie on 2/13/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

final class OdometryMesh {
    
    var sampleCount: Int = 0
    
    let vertexBuffer: MTLBuffer
    
    struct Vertex {
        let position: float4
    }
    
    init(device: MTLDevice) {
        
        self.vertexBuffer = device.makeBuffer(length: 10000 * MemoryLayout<Vertex>.stride, options: [])
    }
    
    func append(sample: Vertex) {
        
        vertexBuffer.contents().storeBytes(of: sample, toByteOffset: sampleCount * MemoryLayout<Vertex>.stride, as: Vertex.self)
        sampleCount += 1
    }
}
