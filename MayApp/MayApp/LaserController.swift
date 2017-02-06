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
    
    init() {
        
        urg_open(&urg, URG_SERIAL, sensorPort, 115200)
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
}
