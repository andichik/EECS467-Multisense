//
//  MatrixUtilities.swift
//  MayApp
//
//  Created by Russell Ladd on 2/5/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import simd

extension float4x4 {
    
    init(scaleX: Float, scaleY: Float) {
        
        self.init([
            float4(scaleX, 0.0, 0.0, 0.0),
            float4(0.0, scaleY, 0.0, 0.0),
            float4(0.0, 0.0, 1.0, 0.0),
            float4(0.0, 0.0, 0.0, 1.0)
        ])
    }
    
    init(angle: Float) {
        
        self.init([
            float4(cos(angle), sin(angle), 0.0, 0.0),
            float4(-sin(angle), cos(angle), 0.0, 0.0),
            float4(0.0, 0.0, 1.0, 0.0),
            float4(0.0, 0.0, 0.0, 1.0)
        ])
    }
    
    init(translation: float3) {
        
        self.init([
            float4(1.0, 0.0, 0.0, 0.0),
            float4(0.0, 1.0, 0.0, 0.0),
            float4(0.0, 0.0, 1.0, 0.0),
            float4(translation.x, translation.y, translation.z, 1.0)
        ])
    }
}
