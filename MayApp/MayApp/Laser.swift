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
    
    static let angleStart = -0.75 * Float(M_PI)
    static let angleWidth =  1.50 * Float(M_PI)
    
    static let minimumDistance: Float = 0.1     // meters
    static let distanceAccuracy: Float = 0.03   // meters = 30mm
}
