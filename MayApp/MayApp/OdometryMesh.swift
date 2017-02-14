//
//  OdometryMesh.swift
//  MayApp
//
//  Created by Yulin Xie on 2/13/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal

final class OdometryMesh {
    
    var sampleCount: Int = 0
    
    let vertexBuffer: MTLBuffer
    
    struct Vertex {
        let x: Float
        let y: Float
    }
    
    init(device: MTLDevice) {
        
        self.vertexBuffer = device.makeBuffer(length: 10000 * MemoryLayout<Vertex>.size, options: [])
    }
    
    func append(sample: Vertex) {
        
        vertexBuffer.contents().storeBytes(of: sample, toByteOffset: sampleCount * MemoryLayout<Vertex>.size, as: Vertex.self)
        sampleCount += 1
    }
}
