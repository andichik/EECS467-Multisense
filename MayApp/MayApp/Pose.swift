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
    
    // TODO: change this to a float4 vector
    public var angle: Float
    
    public func applying(delta: Odometry.Delta) -> Pose {
        
        var translation = float4x4(angle: angle) * delta.dPosition
        translation.w = 0.0
        
        return Pose(position: position + translation, angle: angle + delta.dAngle)
    }
    
    // do the actual pose update
    public mutating func apply(delta: Odometry.Delta) {
        self = applying(delta: delta)
    }
    
    public func applying(transform: float4x4) -> Pose {
        let dAngle = atan2(transform[0, 1], transform[0, 0])
        return Pose(position: transform * position, angle: angle + dAngle)
    }
    
    var matrix: float4x4 {
        return float4x4(translation: position) * float4x4(angle: angle)
    }
}
