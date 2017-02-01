//
//  RobotSessionDataReceiver.swift
//  MayApp
//
//  Created by Russell Ladd on 1/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import ORSSerial

final class RobotSessionDataReceiver: NSObject, SessionDataReceiver, ORSSerialPortDelegate {
    
    let port = ORSSerialPort(path: "/dev/cu.usbmodemFD121")!
    
    override init() {
        
        port.baudRate = 9600
        port.parity = .none
        port.numberOfStopBits = 1
        
        super.init()
        
        port.delegate = self
        
        port.open()
    }
    
    deinit {
        
        port.close()
    }
    
    func receive<T>(_ item: T) {
        
        switch item {
            
        case let robotCommand as RobotCommand:
            print(robotCommand)
            
            let command = "\(robotCommand.leftMotorVelocity)l\(robotCommand.rightMotorVelocity)r"
            
            port.send(command.data(using: .utf8)!)
            
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
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        
        if let string = String(data: data, encoding: .utf8) {
            print(string)
        }
    }
}
