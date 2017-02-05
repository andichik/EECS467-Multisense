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
    
    var urg = urg_t()
    
    let port = ORSSerialPort(path: "/dev/cu.usbmodemFD121")
    
    override init() {
        
        port?.baudRate = 9600
        port?.parity = .none
        port?.numberOfStopBits = 1
        
        urg_open(&urg, URG_SERIAL, "/dev/tty.usbmodemFA131", 115200)
        
        super.init()
        
        port?.delegate = self
        
        port?.open()
    }
    
    deinit {
        
        port?.close()
    }
    
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
    
    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        
        if let string = String(data: data, encoding: .utf8) {
            print(string)
        }
    }
    
    func readLaser() {
        
        urg_start_measurement(&urg, URG_DISTANCE, 1, 0)
        
        var distances = Array<Int>(repeating: 0, count: Int(urg_max_data_size(&urg)))
        let n = Int(urg_get_distance(&urg, &distances, nil))
        
        print(distances.count, n)
        
        var minDistance = 0
        var maxDistance = 0
        urg_distance_min_max(&urg, &minDistance, &maxDistance)
        
        for i in 0..<n {
            
            let angle = urg_index2rad(&urg, Int32(i))
            let distance = distances[i]
            
            print(distance)
        }
    }
}
