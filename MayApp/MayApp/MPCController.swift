//
//  MPCController.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/04/10.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

import Foundation
import MayAppCommon
import simd
import YCML

final class MPCController {
    
    static let baseWidth: Float = 0.4572               // meters
    
    var pose = Pose()
    
    init(){
        //pose = Pose()
    }
    
    func nextState(pose: Pose, path: [uint2]) -> [Float] {
        let problem: YCProblem
    }

}
