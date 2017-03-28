//
//  Laser.swift
//  MayApp
//
//  Created by Russell Ladd on 2/20/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

enum Laser {
    
    static let sampleCount = 1081
    
    static let angleStart = -0.75 * Float.pi
    static let angleWidth =  1.50 * Float.pi
    
    static let angleIncrement = angleWidth / Float(sampleCount - 1)
    
    static let minimumDistance: Float = 0.1     // meters
    static let maximumDistance: Float = 30.0
    static let distanceAccuracy: Float = 0.03   // meters = 30mm
}
