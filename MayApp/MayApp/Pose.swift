//
//  Pose.swift
//  MayApp
//
//  Created by Russell Ladd on 2/16/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import simd

public struct Pose {
    
    public init() {
        
        self.init(position: float4(0.0, 0.0, 0.0, 1.0), angle: 0.0)
    }
    
    public init(position: float4, angle: Float) {
        
        self.position = position
        self.angle = angle
    }
    
    public var position: float4
    public var angle: Float
    
    // do the actual pose update
    public mutating func apply(delta: Odometry.Delta) {
        
        var translation = float4x4(angle: angle) * delta.dPosition
        translation.w = 0.0
        
        position += translation
        angle += delta.dAngle
    }
    
    var matrix: float4x4 {
        return float4x4(translation: position) * float4x4(angle: angle)
    }
}
