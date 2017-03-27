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
        case _ as SensorMeasurement:
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
            return SensorMeasurement.self
        default:
            return nil
        }
    }
}

// MARK: - Robot command

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

// MARK: Sensor measurement

public struct SensorMeasurement {
    
    public init(sequenceNumber: Int, leftEncoder: Int, rightEncoder: Int, laserDistances: Data, cameraVideo: Data, cameraDepth: Data) {
        
        self.sequenceNumber = sequenceNumber
        
        self.leftEncoder = leftEncoder
        self.rightEncoder = rightEncoder
        
        self.laserDistances = laserDistances
        
        self.cameraVideo = cameraVideo
        self.cameraDepth = cameraDepth
    }
    
    public let sequenceNumber: Int
    
    public let leftEncoder: Int             // ticks
    public let rightEncoder: Int            // ticks
    
    public let laserDistances: Data         // millimeters
    
    public let cameraVideo: Data
    public let cameraDepth: Data            // millimeters
}

extension SensorMeasurement: JSONSerializable {
    
    enum Parameter: String {
        case sequenceNumber = "s"
        case leftEncoder = "l"
        case rightEncoder = "r"
        case laserDistances = "d"
        case cameraVideo = "v"
        case cameraDepth = "c"
    }
    
    public init?(json: [String: Any]) {
        
        guard let sequenceNumber = json[Parameter.sequenceNumber.rawValue] as? Int,
            let leftEncoder = json[Parameter.leftEncoder.rawValue] as? Int,
            let rightEncoder = json[Parameter.rightEncoder.rawValue] as? Int,
            let laserDistances = json[Parameter.laserDistances.rawValue] as? String,
            let cameraVideo = json[Parameter.cameraVideo.rawValue] as? String,
            let cameraDepth = json[Parameter.cameraDepth.rawValue] as? String else {
                return nil
        }
        
        self.init(sequenceNumber: sequenceNumber,
                  leftEncoder: leftEncoder,
                  rightEncoder: rightEncoder,
                  laserDistances: Data(base64Encoded: laserDistances)!,
                  cameraVideo: Data(base64Encoded: cameraVideo)!,
                  cameraDepth: Data(base64Encoded: cameraDepth)!)
    }
    
    public func json() -> [String : Any] {
        
        return [Parameter.sequenceNumber.rawValue: sequenceNumber,
                Parameter.leftEncoder.rawValue: leftEncoder,
                Parameter.rightEncoder.rawValue: rightEncoder,
                Parameter.laserDistances.rawValue: laserDistances.base64EncodedString(),
                Parameter.cameraVideo.rawValue: cameraVideo.base64EncodedString(),
                Parameter.cameraDepth.rawValue: cameraDepth.base64EncodedString()]
    }
}
