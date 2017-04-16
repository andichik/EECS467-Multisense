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
    case sensorMeasurement = "sm"
    
    public static var typeKey = "t"
    
    public static func identifier(for item: JSONSerializable) -> String? {
        
        switch item {
        case _ as RobotCommand:
            return robotCommand.rawValue
        case _ as SensorMeasurement:
            return sensorMeasurement.rawValue
        default:
            return nil
        }
    }
    
    public static func type(for identifier: String) -> JSONSerializable.Type? {
        
        switch identifier {
        case robotCommand.rawValue:
            return RobotCommand.self
        case sensorMeasurement.rawValue:
            return SensorMeasurement.self
        default:
            return nil
        }
    }
}

// MARK: - Robot command

public struct RobotCommand {
    
    public init(leftMotorVelocity: Int, rightMotorVelocity: Int, currentPosition: float2, destination: float2, isAutonomous: Bool) {
        
        self.leftMotorVelocity = leftMotorVelocity
        self.rightMotorVelocity = rightMotorVelocity
        
        self.currentPosition = currentPosition
        self.destination = destination
        
        self.isAutonomous = isAutonomous
    }
    
    // This initializer is only used as a convenience for the Mac app to construct commands for the Arduino which doesn't care about the extra properties
    public init(leftMotorVelocity: Int, rightMotorVelocity: Int) {
        
        self.init(leftMotorVelocity: leftMotorVelocity,
                  rightMotorVelocity: rightMotorVelocity,
                  currentPosition: float2(),
                  destination: float2(),
                  isAutonomous: false)
    }
    
    public let leftMotorVelocity: Int
    public let rightMotorVelocity: Int
    
    public let currentPosition: float2
    public let destination: float2
    
    public let isAutonomous: Bool
}

extension RobotCommand: JSONSerializable {
    
    enum Parameter: String {
        case leftMotorVelocity = "l"
        case rightMotorVelocity = "r"
        case currentPosition = "c"
        case destination = "d"
        case isAutonomous = "a"
    }
    
    public init?(json: [String: Any]) {
        
        guard let leftMotorVelocity = json[Parameter.leftMotorVelocity.rawValue] as? Int,
            let rightMotorVelocity = json[Parameter.rightMotorVelocity.rawValue] as? Int,
            let currentPosition = json[Parameter.currentPosition.rawValue] as? [Double], currentPosition.count == 2,
            let destination = json[Parameter.destination.rawValue] as? [Double], destination.count == 2,
            let isAutonomous = json[Parameter.isAutonomous.rawValue] as? Bool else {
            return nil
        }
        
        self.init(leftMotorVelocity: leftMotorVelocity,
                  rightMotorVelocity: rightMotorVelocity,
                  currentPosition: float2(Float(currentPosition[0]), Float(currentPosition[1])),
                  destination: float2(Float(destination[0]), Float(destination[1])),
                  isAutonomous: isAutonomous)
    }
    
    public func json() -> [String : Any] {
        
        return [Parameter.leftMotorVelocity.rawValue: leftMotorVelocity,
                Parameter.rightMotorVelocity.rawValue: rightMotorVelocity,
                Parameter.currentPosition.rawValue: [Double(currentPosition.x), Double(currentPosition.y)],
                Parameter.destination.rawValue: [Double(destination.x), Double(destination.y)],
                Parameter.isAutonomous.rawValue: isAutonomous]
    }
}

extension RobotCommand: CustomStringConvertible {
    
    public var description: String {
        return "RC: (\(leftMotorVelocity), \(rightMotorVelocity))"
    }
}

// MARK: - Sensor measurement

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
