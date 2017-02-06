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
            [scaleX, 0.0, 0.0, 0.0],
            [0.0, scaleY, 0.0, 0.0],
            [0.0, 0.0, 1.0, 0.0],
            [0.0, 0.0, 0.0, 1.0]
        ])
    }
}
