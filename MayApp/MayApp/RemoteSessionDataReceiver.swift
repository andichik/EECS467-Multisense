//
//  RemoteSessionDataReceiver.swift
//  MayApp
//
//  Created by Russell Ladd on 1/30/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import UIKit

final class RemoteSessionDataReceiver: SessionDataReceiver {
    
    let laserDistanceMesh: LaserDistanceMesh
    
    init(laserDistanceMesh: LaserDistanceMesh) {
        
        self.laserDistanceMesh = laserDistanceMesh
    }
    
    var leftEncoderLabel: UILabel!
    var rightEncoderLabel: UILabel!
    
    func receive<T>(_ item: T) {
        
        switch item {
            
        case let laserMeasurement as LaserMeasurement:
            
            guard laserMeasurement.distances.count == laserDistanceMesh.sampleCount else {
                print("Unexpected number of laser measurements: \(laserMeasurement.distances.count)")
                return
            }
            
            let angleStart = Float(M_PI) * -0.75
            let angleWidth = Float(M_PI) *  1.50
            
            let samples = laserMeasurement.distances.enumerated().map { i, distance -> (Float, Float) in
                return (angleStart + angleWidth * Float(i) / Float(laserMeasurement.distances.count),
                        Float(distance) / 10000.0)
            }
            
            laserDistanceMesh.store(samples: samples)
            
            leftEncoderLabel.text = String(laserMeasurement.leftEncoder)
            rightEncoderLabel.text = String(laserMeasurement.rightEncoder)
            
        default: break
        }
    }
}
