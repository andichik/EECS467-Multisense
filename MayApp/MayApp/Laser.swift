//
//  Laser.swift
//  MayApp
//
//  Created by Russell Ladd on 2/20/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

public enum Laser {
    
    public static let sampleCount = 1081
    
    public static let angleStart = -0.75 * Float.pi
    public static let angleWidth =  1.50 * Float.pi
    
    public static let angleIncrement = angleWidth / Float(sampleCount - 1)
    
    public static let minimumDistance: Float = 0.1     // meters
    public static let maximumDistance: Float = 30.0
    public static let distanceAccuracy: Float = 0.03   // meters = 30mm
}
