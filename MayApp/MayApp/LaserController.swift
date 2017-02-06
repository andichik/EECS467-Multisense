//
//  SensorController.swift
//  MayApp
//
//  Created by Russell Ladd on 2/5/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

final class LaserController {
    
    var urg = urg_t()
    
    let sensorPort = "/dev/tty.usbmodemFA131" // Russell
    //let sensorPort = "/dev/cu.usbmodem1421" // Yulin
    
    var timer: Timer? {
        willSet {
            timer?.invalidate()
        }
    }
    
    init() {
        
    }
    
    func measure() -> [Int] {
        
        urg_start_measurement(&urg, URG_DISTANCE, 1, 0)
        
        var distances = Array<Int>(repeating: 0, count: Int(urg_max_data_size(&urg)))
        let sampleCount = Int(urg_get_distance(&urg, &distances, nil))
        
        return Array<Int>(distances.prefix(upTo: sampleCount))
        
        /*var minDistance = 0
        var maxDistance = 0
        urg_distance_min_max(&urg, &minDistance, &maxDistance)
        
        for i in 0..<n {
            
            let angle = urg_index2rad(&urg, Int32(i))
            let distance = distances[i]
            
            print(distance)
        }*/
    }
    
    func measureContinuously(_ block: @escaping ([Int]) -> Void) {
        
        print("LASER ON")
        urg_open(&urg, URG_SERIAL, sensorPort, 115200)
        urg_start_measurement(&urg, URG_DISTANCE, Int32(URG_SCAN_INFINITY), 0)
        
        var distances = Array<Int>(repeating: 0, count: Int(urg_max_data_size(&urg)))
        
        let scanTime = TimeInterval(urg_scan_usec(&urg)) / 1.0E6
        
        if #available(OSX 10.12, *) {
            
            timer = Timer.scheduledTimer(withTimeInterval: scanTime, repeats: true) { [unowned self] timer in
                
                let sampleCount = Int(urg_get_distance(&self.urg, &distances, nil))
                
                guard sampleCount > 0 else {
                    print("LASER ERROR: \(sampleCount)")
                    return
                }
                
                block(Array<Int>(distances.prefix(upTo: sampleCount)))
            }
            
        } else {
            
            // Yulin update your computer please :)
        }
    }
    
    func stopMeasuring() {
        
        print("LASER OFF")
        urg_close(&urg)
        
        timer = nil
    }
}
