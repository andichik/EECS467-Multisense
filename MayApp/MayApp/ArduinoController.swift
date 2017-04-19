//
//  ArduinoController.swift
//  MayApp
//
//  Created by Russell Ladd on 1/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import ORSSerial
import MayAppCommon

final class ArduinoController: NSObject, ORSSerialPortDelegate {
    
    //let arduinoPath = "/dev/cu.usbmodemFD121" // Russell
    let arduinoPath = "/dev/cu.usbmodem1411" // Jasmine
    //let arduinoPath = "/dev/cu.usbmodem14511" // Colin

    var port: ORSSerialPort?
    
    let encoderPacketDescriptor: ORSSerialPacketDescriptor
    
    var encoderLeft = 0
    var encoderRight = 0
    
    override init() {
        
        port = ORSSerialPort(path: arduinoPath)
        
        let regex = try! NSRegularExpression(pattern: "b.*l.*r", options: [])
        encoderPacketDescriptor = ORSSerialPacketDescriptor(regularExpression: regex, maximumPacketLength: 255, userInfo: nil)
        
        super.init()
        
        if let port = port {
            
            port.baudRate = 9600
            port.parity = .none
            port.numberOfStopBits = 1
            
            port.delegate = self
            
            port.open()
            port.startListeningForPackets(matching: encoderPacketDescriptor)
        }
        
    }
    
    deinit {
        
        if let port = port {
            port.stopListeningForPackets(matching: encoderPacketDescriptor)
            port.close()
        }
        
    }
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        
        if port === serialPort {
            port = nil
        }
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        
        print("Opened port \(serialPort.name)")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        
        print("Port \(serialPort.name) encountered error \(error)")
    }
    
    func send(_ robotCommand: RobotCommand) {
        
        let commandString = "\(robotCommand.leftMotorVelocity)l\(robotCommand.rightMotorVelocity)r"
        
        port?.send(commandString.data(using: .utf8)!)
    }
    
    func dist(_ targetPosition: float2, _ currentPosition: float2) -> Float{
        let diff_x = targetPosition[0] - currentPosition[0]
        let diff_y = targetPosition[1] - currentPosition[1]
        
        let dist = sqrt(diff_x*diff_x + diff_y*diff_y)
        return dist
    }
    
    func driveRobot(_ robotCommand: RobotCommand){
        print("isAutnomous \(robotCommand.isAutonomous) currentPosition: \(robotCommand.currentPosition) destination :\(robotCommand.destination) commanded_speed: \(robotCommand.leftMotorVelocity)")
        
        if (robotCommand.isAutonomous == false){
            send(robotCommand)
        }
        else{
              let movingSpeed = 30
              let stopSpeed = 0
              let error = dist(robotCommand.destination, robotCommand.currentPosition)
              if error > 0.1 {
                  let commandString = "\(movingSpeed)l\(movingSpeed)r"
                  port?.send(commandString.data(using: .utf8)!)
            }
            else {
                  let commandString = "\(stopSpeed)l\(stopSpeed)r"
                  port?.send(commandString.data(using: .utf8)!)
            }
        }
    }
    
    
    // Handles receiving encoder values
    func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
        
        if descriptor == self.encoderPacketDescriptor {
            if let string = String(data: packetData, encoding: .utf8) {
                
                let characterSet = CharacterSet(charactersIn: "blr")
                
                let components = string.components(separatedBy: characterSet)
                
                if let left = Int(components[1]), let right = Int(components[2]) {
                    encoderLeft = left
                    encoderRight = right
                }
                
                print(encoderLeft, encoderRight)
            }
        }
    }
}
