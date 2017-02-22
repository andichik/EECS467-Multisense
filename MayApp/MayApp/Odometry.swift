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
    
    static let baseWidth: Float = 0.4572               // meters
    static let metersPerTick: Float = 0.0003483428571  // meters per tick
    
    // MARK: - Variables
    
    private(set) var ticks: (left: Int, right: Int) = (0, 0)
    
    public struct Delta {
        
        var dPosition: float4
        var dAngle: Float
        
        init() {
            
            self.init(dPosition: float4(), dAngle: 0.0)
        }
        
        init(dPosition: float4, dAngle: Float) {
            
            self.dPosition = dPosition
            self.dAngle = dAngle
        }
        
        init(dLeft: Int, dRight: Int) {
            
            let leftMeter = Float(dLeft) * Odometry.metersPerTick
            let rightMeter = Float(dRight) * Odometry.metersPerTick
            
            dAngle = (rightMeter - leftMeter) / Odometry.baseWidth
            
            if dAngle == 0.0 {
                
                dPosition = float4(leftMeter, 0.0, 0.0, 1.0)
                
            } else {
                
                let radius = (rightMeter + leftMeter) / 2.0 / dAngle
                
                let translateDown = float4x4(translation: float3(0.0, -radius, 0.0))
                let rotation = float4x4(angle: dAngle)
                let translateUp = float4x4(translation: float3(0.0, radius, 0.0))
                
                let transform = translateUp * rotation * translateDown
                
                dPosition = transform * float4(0.0, 0.0, 0.0, 1.0)
            }
        }
    }
    
    public func computeDeltaForTicks(left: Int, right: Int) -> Delta {
        
        let dLeft = left - ticks.left
        let dRight = right - ticks.right
        
        ticks = (left, right)
        
        return Delta(dLeft: dLeft, dRight: dRight)
    }
}
