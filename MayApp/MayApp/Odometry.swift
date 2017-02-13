//
//  Odometry.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/02/11.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import simd

final class Odometry {
    
    let baseWidth: Float = 0.4572               //meters
    let ticksPerMeter: Float = 0.0003483428571  // Ticks per meter
    
    private(set) var ticks: (left: Int, right: Int) = (0, 0)
    
    var pos = float4(0.0, 0.0, 0.0, 1.0)
    var angle: Float = 0.0
    
    func updatePos(left: Int, right: Int) {
        
        let dLeft = left - ticks.left
        let dRight = right - ticks.right
        
        ticks = (left, right)
        
        let leftMeter = Float(dLeft) * ticksPerMeter
        let rightMeter = Float(dRight) * ticksPerMeter
        
        let dAngle = (rightMeter - leftMeter) / baseWidth
        
        if dAngle == 0 {
            pos = pos + float4(x: leftMeter*cos(angle), y: leftMeter*sin(angle),z: 0.0, w: 0.0)
            
        } else {
            let cradius = (rightMeter + leftMeter) / 2 / dAngle
            
            let translation = float4(x: cradius*sin(angle + dAngle) - cradius*sin(angle), y: -cradius*cos(angle + dAngle) + cradius*cos(angle), z: 0, w: 1)
            
            let transform = float4x4([
                [cos(dAngle),sin(dAngle),0,0],
                [-sin(dAngle),cos(dAngle),0,0],
                [0,0,1,0],
                translation
                ])
            pos = transform * pos
        }
        
        
        angle += dAngle
    }
    
    
}
