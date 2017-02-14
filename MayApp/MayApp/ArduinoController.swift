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
    
    let arduinoPath = "/dev/tty.usbmodemFA131" // "/dev/cu.usbmodemFD121" // Russell
    //let arduinoPath = "/dev/cu.usbmodem1411" // Yulin
    
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
