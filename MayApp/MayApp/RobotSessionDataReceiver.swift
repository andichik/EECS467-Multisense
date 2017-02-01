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
            
            let command = "\(robotCommand.leftMotorVelocity)l\(robotCommand.rightMotorVelocity)r"
            
            try! command.write(toFile: "/dev/cu.usbmodemFD121", atomically: true, encoding: .utf8)
            
            let response = try! String(contentsOfFile: "/dev/cu.usbmodemFD121", encoding: .utf8)
            print(response)
            
        default: break
        }
    }
}
