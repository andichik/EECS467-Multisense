//
//  SquareMesh.swift
//  MayApp
//
//  Created by Russell Ladd on 2/16/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

final class SquareMesh {
    
    struct Vertex {
        
        let position: float4
        let textureCoordinate: float2
    }
    
    let vertexBuffer: MTLBuffer
    
    let vertexCount: Int
    
    init(device: MTLDevice) {
        
        let verticies = [
            Vertex(position: float4(-1.0, -1.0, 0.0, 1.0), textureCoordinate: float2(0.0, 0.0)),
            Vertex(position: float4( 1.0, -1.0, 0.0, 1.0), textureCoordinate: float2(1.0, 0.0)),
            Vertex(position: float4(-1.0,  1.0, 0.0, 1.0), textureCoordinate: float2(0.0, 1.0)),
            Vertex(position: float4(-1.0,  1.0, 0.0, 1.0), textureCoordinate: float2(0.0, 1.0)),
            Vertex(position: float4( 1.0, -1.0, 0.0, 1.0), textureCoordinate: float2(1.0, 0.0)),
            Vertex(position: float4( 1.0,  1.0, 0.0, 1.0), textureCoordinate: float2(1.0, 1.0))
        ]
        
        vertexBuffer = verticies.withUnsafeBytes { body in
            return device.makeBuffer(bytes: body.baseAddress!, length: body.count, options: [])
        }
        
        vertexCount = verticies.count
    }
}
