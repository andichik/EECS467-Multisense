//
//  Pointcloud.swift
//  MayApp
//
//  Created by Yanqi Liu on 3/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import simd

public struct Point3d{
    
    public init() {
        self.init(position: float4(0.0, 0.0, 0.0, 1.0))
    }
    
    public init(position: float4) {
        self.position = position
    }
    
    public var position: float4
    
}
