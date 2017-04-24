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
    
    public init(angle: Float) {
        
        self.init([
            float4(cos(angle), sin(angle), 0.0, 0.0),
            float4(-sin(angle), cos(angle), 0.0, 0.0),
            float4(0.0, 0.0, 1.0, 0.0),
            float4(0.0, 0.0, 0.0, 1.0)
        ])
    }
    
    public init(rotation: float2x2) {
        
        self.init([
            float4(rotation[0, 0], rotation[0, 1], 0.0, 0.0),
            float4(rotation[1, 0], rotation[1, 1], 0.0, 0.0),
            float4(0.0, 0.0, 1.0, 0.0),
            float4(0.0, 0.0, 0.0, 1.0)
        ])
    }
    
    public init(translation: float2) {
        
        self.init([
            float4(1.0, 0.0, 0.0, 0.0),
            float4(0.0, 1.0, 0.0, 0.0),
            float4(0.0, 0.0, 1.0, 0.0),
            float4(translation.x, translation.y, 0.0, 1.0)
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
    
    var angle: Float {
        return atan2(self[0, 1], self[0, 0])
    }
    
    var translation: float3 {
        return float3(self[3, 0], self[3, 1], self[3, 2])
    }
    
    var magnitude: Float {
        return 0.5 * abs(angle) + length(translation)
    }
}

extension float4 {
    
    public var xy: float2 {
        return float2(x, y)
    }
}

extension float2 {
    
    var angle: Float {
        return atan2(y, x)
    }
}

extension Collection where Iterator.Element == float2, IndexDistance == Int {
    
    var average: float2 {
        return (1.0 / Float(count)) * reduce(float2()) { $0 + $1 }
    }
}

func outer(_ lhs: float2, _ rhs: float2) -> float2x2 {
    return float2x2([rhs.x * lhs, rhs.y * lhs])
}

extension float2x2 {
    
    // From http://scicomp.stackexchange.com/questions/8899/robust-algorithm-for-2x2-svd
    var svd: (u: float2x2, d: float2, vTranspose: float2x2) {
        
        let e = (self[0, 0] + self[1, 1]) / 2.0
        let f = (self[0, 0] - self[1, 1]) / 2.0
        let g = (self[0, 1] + self[1, 0]) / 2.0
        let h = (self[0, 1] - self[1, 0]) / 2.0
        
        let q = sqrt(e * e + h * h)
        let r = sqrt(f * f + g * g)
        
        let sX = q + r
        let sY = q - r
        
        let signSY: Float = (sY >= 0.0) ? 1.0 : -1.0
        
        let a1 = atan2(g, f)
        let a2 = atan2(h, e)
        
        let theta = (a2 - a1) / 2.0
        let phi = (a2 + a1) / 2.0
        
        let u = float2x2([float2(cos(phi), sin(phi)), signSY * float2(-sin(phi), cos(phi))])
        let d = float2(sX, abs(sY))
        let vTranspose = float2x2([float2(cos(theta), sin(theta)), float2(-sin(theta), cos(theta))])
        
        return (u, d, vTranspose)
    }
    
    public init(angle: Float) {
        
        self.init([
            float2(cos(angle), sin(angle)),
            float2(-sin(angle), cos(angle)),
            ])
    }
}


extension Int {
    
    static func divideRoundUp(_ lhs: Int, _ rhs: Int) -> Int {
        return (lhs + rhs - 1) / rhs
    }
}

extension Float {
    
    var angularUnitVector: float2 {
        return float2(cos(self), sin(self))
    }
    
    func anglularAverage(with other: Float) -> Float {
        return (0.5 * (angularUnitVector + other.angularUnitVector)).angle
    }
}
