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
    
    // MARK: - Metrics
    
    static let baseWidth: Float = 0.4572               // meters
    static let metersPerTick: Float = 0.0003483428571  // meters per tick
    
    public private(set) var position = float4(0.0, 0.0, 0.0, 1.0)
    public private(set) var angle: Float = 0.0
    
    public mutating func update(dLeft: Int, dRight: Int) {
        
        let leftMeter = Float(dLeft) * Pose.metersPerTick
        let rightMeter = Float(dRight) * Pose.metersPerTick
        
        let dAngle = (rightMeter - leftMeter) / Pose.baseWidth
        
        if dAngle == 0.0 {
            
            position = position + float4(x: leftMeter*cos(angle), y: leftMeter*sin(angle),z: 0.0, w: 0.0)
            
        } else {
            
            let radius = (rightMeter + leftMeter) / 2 / dAngle
            
            let worldToRobot = float4x4(angle: -angle) * float4x4(translation: float3(-position.x, -position.y, 0.0))
            
            let translateDown = float4x4(translation: float3(0.0, -radius, 0.0))
            let rotation = float4x4(angle: dAngle)
            let translateUp = float4x4(translation: float3(0.0, radius, 0.0))
            
            let robotToWorld = float4x4(translation: float3(position.x, position.y, 0.0)) * float4x4(angle: angle)
            
            let transform = robotToWorld * translateUp * rotation * translateDown * worldToRobot
            
            position = transform * position
        }
        
        angle += dAngle
    }
}
