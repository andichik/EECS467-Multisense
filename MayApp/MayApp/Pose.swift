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
    
    // compute the updates
    public func computeUpdates(dLeft: Int, dRight: Int) -> Odometry.OdometryUpdates {
        
        let leftMeter = Float(dLeft) * Pose.metersPerTick
        let rightMeter = Float(dRight) * Pose.metersPerTick
        
        let dAngle = (rightMeter - leftMeter) / Pose.baseWidth
        
        var newPosition: float4
        
        if dAngle == 0.0 {
            
            newPosition = position + float4(x: leftMeter*cos(angle), y: leftMeter*sin(angle),z: 0.0, w: 0.0)
            
        } else {
            
            let radius = (rightMeter + leftMeter) / 2 / dAngle
            
            let worldToRobot = float4x4(angle: -angle) * float4x4(translation: float3(-position.x, -position.y, 0.0))
            
            let translateDown = float4x4(translation: float3(0.0, -radius, 0.0))
            let rotation = float4x4(angle: dAngle)
            let translateUp = float4x4(translation: float3(0.0, radius, 0.0))
            
            let robotToWorld = float4x4(translation: float3(position.x, position.y, 0.0)) * float4x4(angle: angle)
            
            let transform = robotToWorld * translateUp * rotation * translateDown * worldToRobot
            
            newPosition = transform * position
        }
        
        return Odometry.OdometryUpdates(dx: newPosition.x - position.x, dy: newPosition.y - position.y, dAngle: dAngle)
    }
    
    // do the actual pose update
    public mutating func update(odometryUpdates: Odometry.OdometryUpdates) {
        
        position += float4(odometryUpdates.dx, odometryUpdates.dy, 0.0, 1.0)
        angle += odometryUpdates.dAngle
    }
}
