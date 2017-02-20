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
        odometryUpdates = OdometryUpdates(dx: 0.0, dy: 0.0, dAngle: 0.0)
    }
    
    // MARK: - Variables
    
    private(set) var ticks: (left: Int, right: Int) = (0, 0)
    
    public private(set) var pose = Pose()
    
    public struct OdometryUpdates {
        
        var dx: Float
        var dy: Float
        var dAngle: Float
    }
    
    public private(set) var odometryUpdates: OdometryUpdates
    
    public func updatePos(left: Int, right: Int) {
        
        let dLeft = left - ticks.left
        let dRight = right - ticks.right
        
        ticks = (left, right)
        
        odometryUpdates = pose.computeUpdates(dLeft: dLeft, dRight: dRight)
        pose.update(odometryUpdates: odometryUpdates)
    }
    
    public func reset() {
        
        pose = Pose()
    }
}
