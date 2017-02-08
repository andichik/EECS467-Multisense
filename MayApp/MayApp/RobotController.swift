//
//  RobotController.swift
//  MayApp
//
//  Created by Russell Ladd on 1/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import ORSSerial

final class RobotController: NSObject, SessionDataReceiver, ORSSerialPortDelegate {
    
    let ArduinoPort = "/dev/cu.usbmodemFD121" // Russell
    //let ArduinoPort = "/dev/cu.usbmodem1411" // Yulin
    
    let port: ORSSerialPort?
    
    let encoderRegex: NSRegularExpression
    let encoderPacket: ORSSerialPacketDescriptor
    
    var encoderLeft: Int
    var encoderRight: Int
    
    override init() {
        
        self.port = ORSSerialPort(path: ArduinoPort)
        port?.baudRate = 9600
        port?.parity = .none
        port?.numberOfStopBits = 1
        
        self.encoderRegex = try! NSRegularExpression(pattern: "b.*l.*r", options: [])
        self.encoderPacket = ORSSerialPacketDescriptor(regularExpression: encoderRegex, maximumPacketLength: 255, userInfo: nil)
        self.encoderLeft = 0
        self.encoderRight = 0
        
        super.init()
        
        port?.delegate = self
        
        port?.open()
        
        port?.startListeningForPackets(matching: encoderPacket)
    }
    
    deinit {
        
        port?.stopListeningForPackets(matching: encoderPacket)
        
        port?.close()
    }
    
    // Handles receiving commands from iOS App and sending commands to Arduino
    func receive<T>(_ item: T) {
        
        switch item {
            
        case let robotCommand as RobotCommand:
            print(robotCommand)
            
            let command = "\(robotCommand.leftMotorVelocity)l\(robotCommand.rightMotorVelocity)r"
            
            port?.send(command.data(using: .utf8)!)
            
        default: break
        }
    }
    
    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        
    }
    
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        
        print("Opened port \(serialPort.name)")
    }
    
    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        
        print("Port \(serialPort.name) encountered error \(error)")
    }
    
    /*func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        
        if let string = String(data: data, encoding: .utf8) {
            print(string)
        }
    }*/
    
    // Handles receiving encoder values
    func serialPort(_ serialPort: ORSSerialPort, didReceivePacket packetData: Data, matching descriptor: ORSSerialPacketDescriptor) {
        
        if descriptor == self.encoderPacket {
            if let string = String(data: packetData, encoding: .utf8) {
                //print(string)
                
                let characterSet = CharacterSet(charactersIn: "blr")
                
                let components = string.components(separatedBy: characterSet)
                
                if let left = Int(components[1]), let right = Int(components[2]) {
                    encoderLeft = left
                    encoderRight = right
                }
                
                print(encoderLeft, encoderRight)
                
                /*let nsString = string as NSString
                let results = encoderRegex.matches(in: string, range: nsString.range(of: string))
                for match in results {
                    let leftRange = match.rangeAt(1)
                    if let leftInt = Int(nsString.substring(with: leftRange)) {
                        encoderLeft = leftInt
                    }
                    let rightRange = match.rangeAt(3)
                    if let rightInt = Int(nsString.substring(with: rightRange)) {
                        encoderRight = rightInt
                    }
                }*/
            }
        }
    }
}
