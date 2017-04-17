//
//  PIDController.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/04/9.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

import Foundation
import simd

final class PIDController {
    
    var K_p: Float = 1
    var K_i: Float = 0
    var K_d: Float = 0
    
    var prevError: Float = 0
    var integral: Float = 0
    
    init(){
        
    }
    
    convenience init(K_p: Float, K_i: Float, K_d: Float) {
        self.init()
        self.K_p = K_p
        self.K_i = K_i
        self.K_d = K_d
    }
    
    func nextState(desiredValue: Float, actualValue: Float, deltaT: Float, bias: Float?) -> Float {
        let error = desiredValue - actualValue
        integral = integral + (error * deltaT)
        let derivative = (error - prevError)/deltaT
        
        var output = K_p * error
        output += K_i * integral
        output += K_d * derivative + bias!
        
        prevError = error
        
        return output
    }
    
    func reset() {
        prevError = 0
        integral = 0
    }
}
