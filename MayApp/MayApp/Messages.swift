//
//  Messages.swift
//  MayApp
//
//  Created by Russell Ladd on 1/30/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

// MARK: - Message Type

public enum MessageType: String, JSONSerializer {
    
    case robotCommand = "rc"
    case laserMeasurement = "lm"
    
    public static var typeKey = "t"
    
    public static func identifier(for item: JSONSerializable) -> String? {
        
        switch item {
        case _ as RobotCommand:
            return robotCommand.rawValue
        case _ as LaserMeasurement:
            return laserMeasurement.rawValue
        default:
            return nil
        }
    }
    
    public static func type(for identifier: String) -> JSONSerializable.Type? {
        
        switch identifier {
        case robotCommand.rawValue:
            return RobotCommand.self
        case laserMeasurement.rawValue:
            return LaserMeasurement.self
        default:
            return nil
        }
    }
}

// MARK: - Robot Command

public struct RobotCommand {
    
    public init(leftMotorVelocity: Int, rightMotorVelocity: Int) {
        
        self.leftMotorVelocity = leftMotorVelocity
        self.rightMotorVelocity = rightMotorVelocity
    }
    
    public let leftMotorVelocity: Int
    public let rightMotorVelocity: Int
}

extension RobotCommand: JSONSerializable {
    
    enum Paramter: String {
        case leftMotorVelocity = "l"
        case rightMotorVelocity = "r"
    }
    
    public init?(json: [String: Any]) {
        
        guard let leftMotorVelocity = json[Paramter.leftMotorVelocity.rawValue] as? Int,
            let rightMotorVelocity = json[Paramter.rightMotorVelocity.rawValue] as? Int else {
            return nil
        }
        
        self.init(leftMotorVelocity: leftMotorVelocity, rightMotorVelocity: rightMotorVelocity)
    }
    
    public func json() -> [String : Any] {
        
        return [Paramter.leftMotorVelocity.rawValue: leftMotorVelocity,
                Paramter.rightMotorVelocity.rawValue: rightMotorVelocity]
    }
}

extension RobotCommand: CustomStringConvertible {
    
    public var description: String {
        return "RC: (\(leftMotorVelocity), \(rightMotorVelocity))"
    }
}

// MARK: Laser Reading

public struct LaserMeasurement {
    
    public init(distances: [Int], leftEncoder: Int, rightEncoder: Int) {
        
        self.distances = distances
        
        self.leftEncoder = leftEncoder
        self.rightEncoder = rightEncoder
    }
    
    public let distances: [Int]
    
    public let leftEncoder: Int
    public let rightEncoder: Int
}

extension LaserMeasurement: JSONSerializable {
    
    enum Paramter: String {
        case distances = "d"
        case leftEncoder = "l"
        case rightEncoder = "r"
    }
    
    public init?(json: [String: Any]) {
        
        guard let distances = json[Paramter.distances.rawValue] as? [Int], let leftEncoder = json[Paramter.leftEncoder.rawValue] as? Int, let rightEncoder = json[Paramter.rightEncoder.rawValue] as? Int else {
                return nil
        }
        
        self.init(distances: distances, leftEncoder: leftEncoder, rightEncoder: rightEncoder)
    }
    
    public func json() -> [String : Any] {
        
        return [Paramter.distances.rawValue: distances, Paramter.leftEncoder.rawValue: leftEncoder, Paramter.rightEncoder.rawValue: rightEncoder]
    }
}
