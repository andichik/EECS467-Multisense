//
//  RobotSessionDataReceiver.swift
//  MayApp
//
//  Created by Russell Ladd on 1/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

final class RobotSessionDataReceiver: SessionDataReceiver {
    
    func receive<T>(_ item: T) {
        
        switch item {
            
        case let robotCommand as RobotCommand:
            print(robotCommand)
            
        default: break
        }
    }
}
