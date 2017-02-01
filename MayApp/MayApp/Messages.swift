//
//  Messages.swift
//  MayApp
//
//  Created by Russell Ladd on 1/30/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

// MARK: - Message Type

enum MessageType: String, JSONSerializer {
    
    case robotCommand = "rc"
    
    static var typeKey = "t"
    
    static func identifier(for item: JSONSerializable) -> String? {
        
        switch item {
        case _ as RobotCommand:
            return robotCommand.rawValue
        default:
            return nil
        }
    }
    
    static func type(for identifier: String) -> JSONSerializable.Type? {
        
        switch identifier {
        case robotCommand.rawValue:
            return RobotCommand.self
        default:
            return nil
        }
    }
}

// MARK: - Robot Command

struct RobotCommand {
    
    let leftMotorVelocity: Int
    let rightMotorVelocity: Int
}

extension RobotCommand: JSONSerializable {
    
    enum Paramter: String {
        case leftMotorVelocity = "l"
        case rightMotorVelocity = "r"
    }
    
    init?(json: [String: Any]) {
        
        guard let leftMotorVelocity = json[Paramter.leftMotorVelocity.rawValue] as? Int,
            let rightMotorVelocity = json[Paramter.rightMotorVelocity.rawValue] as? Int else {
            return nil
        }
        
        self.init(leftMotorVelocity: leftMotorVelocity, rightMotorVelocity: rightMotorVelocity)
    }
    
    func json() -> [String : Any] {
        
        return [Paramter.leftMotorVelocity.rawValue: leftMotorVelocity,
                Paramter.rightMotorVelocity.rawValue: rightMotorVelocity]
    }
}

extension RobotCommand: CustomStringConvertible {
    
    var description: String {
        return "RC: (\(leftMotorVelocity), \(rightMotorVelocity))"
    }
}
