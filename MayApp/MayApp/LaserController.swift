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
    
    var activity: NSObjectProtocol?
    
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
        
        // Register this activity with the system to ensure our app gets resource priority and is not put into App Nap
        activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated, .latencyCritical], reason: "Streaming laser scans to remote.")
        
        print("LASER ON")
        guard urg_open(&urg, URG_SERIAL, sensorPort, 115200) == 0 else {
            
            // Short circuit path in case laser is not connected
            
            if #available(OSX 10.12, *) {
                let distances = Array<Int>(repeating: 2000, count: 1081)
                
                timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                    block(distances)
                }
            }
            
            return
        }
        
        var distances = Array<Int>(repeating: 0, count: Int(urg_max_data_size(&urg)))
        
        let scanTime = TimeInterval(urg_scan_usec(&urg)) / 1.0E6
        
        if #available(OSX 10.12, *) {
            
            timer = Timer.scheduledTimer(withTimeInterval: scanTime, repeats: true) { [unowned self] timer in
                
                // Start measurement for 1 scan and retreive data
                
                // NOTE: We choose 1 scan instead of URG_SCAN_INFINITY because URG_SCAN_INFINITY requires really aggressive polling of the device
                // If this timer block were occasionally skipped, the laser would get farther and farther ahead of the computer, filling up an internal buffer in the laser
                // This would cause our data to fall farther and farther out of sync until the laser's internal buffer overflowed causing an error
                // This method avoids that problem by only asking for one scan at a time and then immediately pulling the data
                
                urg_start_measurement(&self.urg, URG_DISTANCE, 1, 0)
                let sampleCount = Int(urg_get_distance(&self.urg, &distances, nil))
                
                guard sampleCount > 0 else {
                    print("LASER ERROR: \(sampleCount)")
                    // TODO: close and reopen
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
        
        ProcessInfo.processInfo.endActivity(activity!)
    }
}
