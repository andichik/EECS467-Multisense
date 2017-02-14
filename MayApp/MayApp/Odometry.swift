//
//  Odometry.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/02/11.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import simd

public final class Odometry {
    
    // MARK: - Initializer
    
    public init() {
        
    }
    
    // MARK: - Metrics
    
    let baseWidth: Float = 0.4572               // meters
    let metersPerTick: Float = 0.0003483428571  // meters per tick
    
    // MARK: - Variables
    
    private(set) var ticks: (left: Int, right: Int) = (0, 0)
    
    public private(set) var position = float4(0.0, 0.0, 0.0, 1.0)
    public private(set) var angle: Float = 0.0
    
    public func updatePos(left: Int, right: Int) {
        
        let dLeft = left - ticks.left
        let dRight = right - ticks.right
        
        ticks = (left, right)
        
        let leftMeter = Float(dLeft) * metersPerTick
        let rightMeter = Float(dRight) * metersPerTick
        
        let dAngle = (rightMeter - leftMeter) / baseWidth
        
        if dAngle == 0 {
            position = position + float4(x: leftMeter*cos(angle), y: leftMeter*sin(angle),z: 0.0, w: 0.0)
            
        } else {
            let cradius = (rightMeter + leftMeter) / 2 / dAngle
            
            let worldToRobot = float4x4(angle: -angle) * float4x4(translation: float3(-position.x, -position.y, 0.0))
            
            let translateDown = float4x4(translation: float3(0.0, -cradius, 0.0))
            let rotation = float4x4(angle: dAngle)
            let translateUp = float4x4(translation: float3(0.0, cradius, 0.0))
            
            let robotToWorld = float4x4(translation: float3(position.x, position.y, 0.0)) * float4x4(angle: angle)
            
            let transform = robotToWorld * translateUp * rotation * translateDown * worldToRobot
            
            //let translation = float4(cradius*sin(angle + dAngle) - cradius*sin(angle), -cradius*cos(angle + dAngle) + cradius*cos(angle), 0.0, 1.0)
            /*let translation = float4(cradius*sin(dAngle), -cradius * cos(dAngle) + cradius, 0.0, 1.0)
            
            let transform = float4x4([
                [cos(dAngle),sin(dAngle),0,0],
                [-sin(dAngle),cos(dAngle),0,0],
                [0,0,1,0],
                translation
            ])*/
            
            position = transform * position
        }
        
        
        angle += dAngle
    }
    
    public func reset() {
        
        position = float4(0.0, 0.0, 0.0, 1.0)
        angle = 0.0
    }
}
