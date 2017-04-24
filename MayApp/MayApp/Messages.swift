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
    case transformTransmit = "tt"
    case remoteUpdate = "ru"
    
    public static var typeKey = "t"
    
    public static func identifier(for item: JSONSerializable) -> String? {
        
        switch item {
        case _ as RobotCommand:
            return robotCommand.rawValue
        case _ as SensorMeasurement:
            return sensorMeasurement.rawValue
        case _ as MapUpdate:
            return mapUpdate.rawValue
        case _ as TransformTransmit:
            return transformTransmit.rawValue
        case _ as RemoteUpdate:
            return remoteUpdate.rawValue
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
        case transformTransmit.rawValue:
            return TransformTransmit.self
        case remoteUpdate.rawValue:
            return RemoteUpdate.self
        default:
            return nil
        }
    }
}

// MARK: - Robot command

public struct RobotCommand {
    
    public init(leftMotorVelocity: Int, rightMotorVelocity: Int, currentPosition: float2, currentAngle: Float, destination: float2, destinationAngle: Float, isAutonomous: Bool) {
        
        self.leftMotorVelocity = leftMotorVelocity
        self.rightMotorVelocity = rightMotorVelocity
        
        self.currentPosition = currentPosition
        self.destination = destination
        self.currentAngle = currentAngle
        self.destinationAngle = destinationAngle
        
        self.isAutonomous = isAutonomous
    }
    
    // This initializer is only used as a convenience for the Mac app to construct commands for the Arduino which doesn't care about the extra properties
    public init(leftMotorVelocity: Int, rightMotorVelocity: Int) {
        
        self.init(leftMotorVelocity: leftMotorVelocity,
                  rightMotorVelocity: rightMotorVelocity,
                  currentPosition: float2(),
                  currentAngle: Float(),
                  destination: float2(),
                  destinationAngle: Float(),
                  isAutonomous: false)
    }
    
    public let leftMotorVelocity: Int
    public let rightMotorVelocity: Int
    
    public let currentPosition: float2
    public let destination: float2
    
    public let currentAngle: Float
    public let destinationAngle: Float
    
    public let isAutonomous: Bool
}

extension RobotCommand: JSONSerializable {
    
    enum Parameter: String {
        case leftMotorVelocity = "l"
        case rightMotorVelocity = "r"
        case currentPosition = "c"
        case currentAngle = "ca"
        case destination = "d"
        case destinationAngle = "da"
        case isAutonomous = "a"
    }
    
    public init?(json: [String: Any]) {
        
        guard let leftMotorVelocity = json[Parameter.leftMotorVelocity.rawValue] as? Int,
            let rightMotorVelocity = json[Parameter.rightMotorVelocity.rawValue] as? Int,
            let currentPosition = json[Parameter.currentPosition.rawValue] as? [Double], currentPosition.count == 2,
            let currentAngle = json[Parameter.currentAngle.rawValue] as? Double,
            let destination = json[Parameter.destination.rawValue] as? [Double], destination.count == 2,
            let destinationAngle = json[Parameter.destinationAngle.rawValue] as? Double,
            let isAutonomous = json[Parameter.isAutonomous.rawValue] as? Bool else {
            return nil
        }
        
        self.init(leftMotorVelocity: leftMotorVelocity,
                  rightMotorVelocity: rightMotorVelocity,
                  currentPosition: float2(Float(currentPosition[0]), Float(currentPosition[1])),
                  currentAngle: Float(currentAngle),
                  destination: float2(Float(destination[0]), Float(destination[1])),
                  destinationAngle: Float(destinationAngle),
                  isAutonomous: isAutonomous)
    }
    
    public func json() -> [String : Any] {
        
        return [Parameter.leftMotorVelocity.rawValue: leftMotorVelocity,
                Parameter.rightMotorVelocity.rawValue: rightMotorVelocity,
                Parameter.currentPosition.rawValue: [Double(currentPosition.x), Double(currentPosition.y)],
                Parameter.currentAngle.rawValue: currentAngle,
                Parameter.destination.rawValue: [Double(destination.x), Double(destination.y)],
                Parameter.destinationAngle.rawValue: destinationAngle,
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

// MARK: - Map update

public struct MapUpdate {
    
    public init (sequenceNumber: Int, pointDictionary: [UUID: MapPoint], connections: [(UUID, UUID)], robotId: UUID, pose: Pose, otherPose: Pose, roomSigns: [String: float4]) {
        
        self.sequenceNumber = sequenceNumber
        self.pointDictionary = pointDictionary
        self.connections = connections
        self.robotId = robotId
        self.pose = pose
        self.otherPose = otherPose
        self.roomSigns = roomSigns
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
    public let connections: [(UUID, UUID)]
    public let robotId: UUID
    public let pose: Pose
    public let otherPose: Pose
    public let roomSigns: [String: float4]
    //public var UUIDs: [String]
    //public var mapPoints: [String: Any]//[MapPoint]
    
}

extension MapUpdate: JSONSerializable {
    
    enum Parameter: String {
        case sequenceNumber = "s"
        case robotId = "i"
        //case UUIDs = "u"
        //case mapPointsLength = "l"
        case mapPoints = "p"
        case connections = "c"
        case pose = "po"
        case otherPose = "op"
        case roomSigns = "rs"
    }
    
    public init?(json: [String: Any]) {
        
        guard let sequenceNumber = json[Parameter.sequenceNumber.rawValue] as? Int,
            let jsonPoints = json[Parameter.mapPoints.rawValue] as? [String: Any],
            let connectionsJSON = json[Parameter.connections.rawValue] as? [[String]],
            let robotIdString = json[Parameter.robotId.rawValue] as? String,
            let poseJson = json[Parameter.pose.rawValue] as? [String: Any],
            let pose = Pose(json: poseJson),
            let otherPoseJson = json[Parameter.otherPose.rawValue] as? [String: Any],
            let otherPose = Pose(json: otherPoseJson),
            let roomSignsJSON = json[Parameter.roomSigns.rawValue] as? [String: [Float]] else {
            return nil
        }
        
        var pointDict = [UUID: MapPoint]()
        
        for (key, values) in jsonPoints {
            if let json = (values as? [String: Any]) {
                if let uuid = UUID(uuidString: key) {
                    pointDict[uuid] = MapPoint(json: json)
                }
            }
        }
        
        let connections = connectionsJSON.map { (UUID(uuidString: $0[0])!, UUID(uuidString: $0[1])!) }
        
        let robotId = UUID(uuidString: robotIdString)!
        
        var roomSigns = [String: float4]()
        for (name, position) in roomSignsJSON {
            roomSigns[name] = float4(position)
        }
        
        self.init(sequenceNumber: sequenceNumber, pointDictionary: pointDict, connections: connections, robotId: robotId, pose: pose, otherPose: otherPose, roomSigns: roomSigns)
    }
    
    public func json() -> [String: Any] {
        
        var jsonPoints = [String : [String: Any]]()
        for (key, value) in pointDictionary {
            jsonPoints[key.uuidString] = value.json()
        }
        
        let connectionsJSON = connections.map { [$0.0.uuidString, $0.1.uuidString] }
        
        var roomSignsJSON = [String: [Float]]()
        for (name, position) in roomSigns {
            roomSignsJSON[name] = [position.x, position.y, position.z, position.w]
        }
        
        return [Parameter.sequenceNumber.rawValue: sequenceNumber,
                Parameter.robotId.rawValue: robotId.uuidString,
                Parameter.mapPoints.rawValue: jsonPoints,
                Parameter.connections.rawValue: connectionsJSON,
                Parameter.pose.rawValue: pose.json(),
                Parameter.otherPose.rawValue: otherPose.json(),
                Parameter.roomSigns.rawValue: roomSignsJSON]
    }
}

// MARK: Transform transmit

public struct TransformTransmit {
    /*public init(translation: float2, rotation: float2x2) {
        self.translation = translation
        self.rotation = rotation
    }*/
    
    public init(transform: float4x4) {
        self.transform = transform
    }
    
    public let transform: float4x4
    //public let translation: float2
    //public let rotation: float2x2
}

extension TransformTransmit: JSONSerializable {
    enum Parameter: String {
        case transform = "r"
        //case translation = "l"
        //case rotation = "r"
    }
    
    public init?(json: [String: Any]) {
        guard let transformJson = json[Parameter.transform.rawValue] as? [Float] else {
        //guard let translate = json[Parameter.translation.rawValue] as? [Float],
        //    let rotate = json[Parameter.rotation.rawValue] as? [Float] else {
            return nil
        }
        
        let transform = float4x4([
            float4(transformJson[0], transformJson[1], transformJson[2], transformJson[3]),
            float4(transformJson[4], transformJson[5], transformJson[6], transformJson[7]),
            float4(transformJson[8], transformJson[9], transformJson[10], transformJson[11]),
            float4(transformJson[12], transformJson[13], transformJson[14], transformJson[15])
        ])

        
        self.init(transform: transform)
        
        /*let translation = float2(translate[0], translate[1])
        
        //var rotation = float2x2(diagonal: float2(1.0))
        let row1 = float2(rotate[0], rotate[2])
        let row2 = float2(rotate[1], rotate[3])
        let rows: [float2] = [row1, row2]
        
        let rotation = float2x2(rows: rows)
        
        self.init(translation: translation, rotation: rotation)*/
    }
    
    public func json() -> [String: Any] {
        var transformArray = [Float]()
        transformArray.append(self.transform.cmatrix.columns.0.x)
        transformArray.append(self.transform.cmatrix.columns.0.y)
        transformArray.append(self.transform.cmatrix.columns.0.z)
        transformArray.append(self.transform.cmatrix.columns.0.w)

        transformArray.append(self.transform.cmatrix.columns.1.x)
        transformArray.append(self.transform.cmatrix.columns.1.y)
        transformArray.append(self.transform.cmatrix.columns.1.z)
        transformArray.append(self.transform.cmatrix.columns.1.w)

        transformArray.append(self.transform.cmatrix.columns.2.x)
        transformArray.append(self.transform.cmatrix.columns.2.y)
        transformArray.append(self.transform.cmatrix.columns.2.z)
        transformArray.append(self.transform.cmatrix.columns.2.w)

        transformArray.append(self.transform.cmatrix.columns.3.x)
        transformArray.append(self.transform.cmatrix.columns.3.y)
        transformArray.append(self.transform.cmatrix.columns.3.z)
        transformArray.append(self.transform.cmatrix.columns.3.w)

        return [Parameter.transform.rawValue: transformArray]
    }
}

// MARK: - RemoteUpdate

public struct RemoteUpdate {
    
    public let sensorMeasurement: SensorMeasurement
    public let mapUpdate: MapUpdate
    
    public init(sensorMeasurement: SensorMeasurement, mapUpdate: MapUpdate) {
        self.sensorMeasurement = sensorMeasurement
        self.mapUpdate = mapUpdate
    }
}

extension RemoteUpdate: JSONSerializable {
    
    enum Parameter: String {
        case sensorMeasurement = "sm"
        case mapUpdate = "mu"
    }
    
    public init?(json: [String : Any]) {
        
        guard let sensorMeasurementJSON = json[Parameter.sensorMeasurement.rawValue] as? [String: Any],
            let sensorMeasurement = SensorMeasurement(json: sensorMeasurementJSON),
            let mapUpdateJSON = json[Parameter.mapUpdate.rawValue] as? [String: Any],
            let mapUpdate = MapUpdate(json: mapUpdateJSON) else {
            return nil
        }
        
        self.init(sensorMeasurement: sensorMeasurement, mapUpdate: mapUpdate)
    }
    
    public func json() -> [String: Any] {
        return [Parameter.sensorMeasurement.rawValue: sensorMeasurement.json(),
                Parameter.mapUpdate.rawValue: mapUpdate.json()]
    }
}

// MARK: - UUID extensions

func >(lhs: UUID, rhs: UUID) -> Bool {
    if lhs.uuid.0 != rhs.uuid.0 {
        return lhs.uuid.0 > rhs.uuid.0
    }
    if lhs.uuid.1 != rhs.uuid.1 {
        return lhs.uuid.1 > rhs.uuid.1
    }
    if lhs.uuid.2 != rhs.uuid.2 {
        return lhs.uuid.2 > rhs.uuid.2
    }
    if lhs.uuid.3 != rhs.uuid.3 {
        return lhs.uuid.3 > rhs.uuid.3
    }
    if lhs.uuid.4 != rhs.uuid.4 {
        return lhs.uuid.4 > rhs.uuid.4
    }
    if lhs.uuid.5 != rhs.uuid.5 {
        return lhs.uuid.5 > rhs.uuid.5
    }
    if lhs.uuid.6 != rhs.uuid.6 {
        return lhs.uuid.6 > rhs.uuid.6
    }
    if lhs.uuid.7 != rhs.uuid.7 {
        return lhs.uuid.7 > rhs.uuid.7
    }
    if lhs.uuid.8 != rhs.uuid.8 {
        return lhs.uuid.8 > rhs.uuid.8
    }
    if lhs.uuid.9 != rhs.uuid.9 {
        return lhs.uuid.9 > rhs.uuid.9
    }
    if lhs.uuid.10 != rhs.uuid.10 {
        return lhs.uuid.10 > rhs.uuid.10
    }
    if lhs.uuid.11 != rhs.uuid.11 {
        return lhs.uuid.11 > rhs.uuid.11
    }
    if lhs.uuid.12 != rhs.uuid.12 {
        return lhs.uuid.12 > rhs.uuid.12
    }
    if lhs.uuid.13 != rhs.uuid.13 {
        return lhs.uuid.13 > rhs.uuid.13
    }
    if lhs.uuid.14 != rhs.uuid.14 {
        return lhs.uuid.14 > rhs.uuid.14
    }
    return lhs.uuid.15 > rhs.uuid.15
}

extension UUID {
    public static func greater(lhs: UUID, rhs: UUID) -> Bool {
        return lhs > rhs
    }
}
