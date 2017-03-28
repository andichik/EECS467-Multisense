//
//  MathUtilities.swift
//  MayApp
//
//  Created by Russell Ladd on 2/5/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import simd

extension float4x4 {
    
    init(scaleX: Float, scaleY: Float) {
        
        self.init([
            float4(scaleX, 0.0, 0.0, 0.0),
            float4(0.0, scaleY, 0.0, 0.0),
            float4(0.0, 0.0, 1.0, 0.0),
            float4(0.0, 0.0, 0.0, 1.0)
        ])
    }
    
    init(angle: Float) {
        
        self.init([
            float4(cos(angle), sin(angle), 0.0, 0.0),
            float4(-sin(angle), cos(angle), 0.0, 0.0),
            float4(0.0, 0.0, 1.0, 0.0),
            float4(0.0, 0.0, 0.0, 1.0)
        ])
    }
    
    init(translation: float3) {
        
        self.init([
            float4(1.0, 0.0, 0.0, 0.0),
            float4(0.0, 1.0, 0.0, 0.0),
            float4(0.0, 0.0, 1.0, 0.0),
            float4(translation.x, translation.y, translation.z, 1.0)
        ])
    }
    
    init(translation: float4) {
        
        self.init([
            float4(1.0, 0.0, 0.0, 0.0),
            float4(0.0, 1.0, 0.0, 0.0),
            float4(0.0, 0.0, 1.0, 0.0),
            translation
        ])
    }
    
    init(rotationAbout axis: float3, by angle: Float) {
        
        let s = sin(angle)
        let c = cos(angle)
        
        let x = float4(
            axis.x * axis.x + (1.0 - axis.x * axis.x) * c,
            axis.x * axis.y * (1.0 - c) - axis.z * s,
            axis.x * axis.z * (1.0 - c) + axis.y * s,
            0.0
        )
        
        let y = float4(
            axis.x * axis.y * (1.0 - c) + axis.z * s,
            axis.y * axis.y + (1.0 - axis.y * axis.y) * c,
            axis.y * axis.z * (1.0 - c) - axis.x * s,
            0.0
        )
        
        let z = float4(
            axis.x * axis.z * (1.0 - c) - axis.y * s,
            axis.y * axis.z * (1.0 - c) + axis.x * s,
            axis.z * axis.z + (1.0 - axis.z * axis.z) * c,
            0.0
        )
        
        let w = float4(0.0, 0.0, 0.0, 1.0)
        
        self.init([x, y, z, w])
    }
    
    init(perspectiveWithAspectRatio aspectRatio: Float, fieldOfViewY fovy: Float, near: Float, far: Float) {
        
        let yScale = 1.0 / tan(fovy * 0.5)
        let xScale = yScale / aspectRatio
        let zRange = far - near
        let zScale = -(far + near) / zRange
        let wzScale = -2.0 * far * near / zRange
        
        self.init([
            [xScale, 0.0, 0.0, 0.0],
            [0.0, yScale, 0.0, 0.0],
            [0.0, 0.0, zScale, -1.0],
            [0.0, 0.0, wzScale, 0.0]
            ])
    }
    
}

extension Int {
    
    static func divideRoundUp(_ lhs: Int, _ rhs: Int) -> Int {
        return (lhs + rhs - 1) / rhs
    }
}
