//
//  Messages.swift
//  MayApp
//
//  Created by Russell Ladd on 1/30/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

enum MessageType: String, JSONEncodableTyper {
    
    case robotCommand = "rc"
    
    static func type(for identifier: String) -> TypedJSONEncodable.Type? {
        
        guard let messageType = MessageType(rawValue: identifier) else {
            return nil
        }
        
        switch messageType {
        case .robotCommand:
            return RobotCommand.self
        }
    }
}

struct RobotCommand {
    
    let leftMotorVelocity: Int
    let rightMototVelocity: Int
}

extension RobotCommand: TypedJSONEncodable {
    
    enum Paramter: String {
        case leftMotorVelocity = "l"
        case rightMotorVelocity = "r"
    }
    
    init?(jsonData: [String: Any]) {
        
        guard let leftMotorVelocity = jsonData[Paramter.leftMotorVelocity.rawValue] as? Int, let rightMototVelocity = jsonData[Paramter.rightMotorVelocity.rawValue] as? Int else {
            return nil
        }
        
        self.leftMotorVelocity = leftMotorVelocity
        self.rightMototVelocity = rightMototVelocity
    }
    
    func encodedJSONProperties() -> [String : Any] {
        
        return [Paramter.leftMotorVelocity.rawValue: leftMotorVelocity, Paramter.rightMotorVelocity.rawValue: rightMototVelocity]
    }
    
    static var type = MessageType.robotCommand.rawValue
}

extension RobotCommand: CustomStringConvertible {
    
    var description: String {
        return "RC: (\(leftMotorVelocity), \(rightMototVelocity))"
    }
}
