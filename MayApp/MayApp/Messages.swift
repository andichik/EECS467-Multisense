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
    case mapUpdate = "mu"
    
    public static var typeKey = "t"
    
    public static func identifier(for item: JSONSerializable) -> String? {
        
        switch item {
        case _ as RobotCommand:
            return robotCommand.rawValue
        case _ as SensorMeasurement:
            return sensorMeasurement.rawValue
        case _ as MapUpdate:
            return mapUpdate.rawValue
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
        case mapUpdate.rawValue:
            return MapUpdate.self
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

public struct MapUpdate {
    
    public init (sequenceNumber: Int, pointDictionary: [UUID: MapPoint]) {
        
        self.sequenceNumber = sequenceNumber
        self.pointDictionary = pointDictionary
        /*self.UUIDs = [String]()
        self.mapPoints = [MapPoint]()
        
        for (key, value) in pointDictionary {
            UUIDs.append(key.uuidString)
            mapPoints.append(value.json())
        }*/
    }
    
    /*init (sequenceNumber: Int, UUIDs: [String], mapPoints: [MapPoint]) {
        self.sequenceNumber = sequenceNumber
        self.pointDictionary = pointDictionary
        //self.UUIDs = UUIDs
        //self.mapPoints = mapPoints
    }*/
    
    public let sequenceNumber: Int
    public let pointDictionary: [UUID: MapPoint]
    //public var UUIDs: [String]
    //public var mapPoints: [String: Any]//[MapPoint]
    
}

extension MapUpdate: JSONSerializable {
    
    enum Parameter: String {
        case sequenceNumber = "s"
        //case UUIDs = "u"
        //case mapPointsLength = "l"
        case mapPoints = "p"
    }
    
    public init?(json: [String: Any]) {
        
        guard let sequenceNumber = json[Parameter.sequenceNumber.rawValue] as? Int,
        let jsonPoints = json[Parameter.mapPoints.rawValue] as? [String : Any]
            else {
                return nil
        }
        
        var pointDict = [UUID : MapPoint]()
        
        for (key, values) in jsonPoints {
            if let json = (values as? [String: Any]) {
                if let uuid = UUID(uuidString: key) {
                    pointDict[uuid] = MapPoint.init(json: json)
                }
            }
        }
        
        self.init(sequenceNumber: sequenceNumber, pointDictionary: pointDict)
    }
    
    public func json() -> [String: Any] {
        var jsonPoints = [String : [String: Any]]()
        for (key, value) in pointDictionary {
            jsonPoints[key.uuidString] = value.json()
        }
        
        return [Parameter.sequenceNumber.rawValue: sequenceNumber,
                Parameter.mapPoints.rawValue: jsonPoints]
    }
}

extension UUID: JSONSerializable {
    enum Parameter: String {
        case uuidString = "u"
    }
    
    public init?(json: [String: Any]) {
        guard let uuidString = json[Parameter.uuidString.rawValue] as? String else {
            return nil
        }
        self.init(uuidString: uuidString)
    }
    
    public func json() -> [String: Any] {
        return [Parameter.uuidString.rawValue: uuidString]
    }
}

extension Float: JSONSerializable {
    enum Parameter: String {
        case value = "f"
    }
    
    public init?(json: [String: Any]) {
        guard let value = json[Parameter.value.rawValue] as? Float else {
            return nil
        }
        self.init(Float(value))
    }
    
    public func json() -> [String: Any] {
        return [Parameter.value.rawValue: self]
    }
}
