//
//  VectorMapConnection.swift
//  MayApp
//
//  Created by Russell Ladd on 4/3/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import simd

extension MapPoint {
    
    func distance(to other: MapPoint) -> Float {
        return simd.distance(float2(position.x, position.y), float2(other.position.x, other.position.y))
    }
    
    func applying(transform: float4x4) -> MapPoint {
        // FIXME: start angle and end angle need to rotate too
        // Change them to be "vectors" float4 with last component 0.0 so we can just multiply by transform
        let angle = atan2(transform[0, 1], transform[0, 0])
        return MapPoint(position: transform * position, stddev: stddev, startAngle: startAngle + angle, endAngle: endAngle + angle, count: count)
    }
    
    func merged(with other: MapPoint) -> MapPoint {
        
        /*var result = old
        
        // update normal distribution's means, stddev (on distance)
        // http://math.stackexchange.com/questions/250927/iteratively-updating-a-normal-distribution
        result.position.x = old.position.x + (new.position.x - old.position.x)/Float(old.count)
        result.position.y = old.position.y + (new.position.y - old.position.y)/Float(old.count)
        
        result.count += 1
        
        result.stddev.x = sqrt(old.stddev.x + (new.position.x - old.position.x) * (new.position.x - result.position.x)/Float(result.count))
        result.stddev.y = sqrt(old.stddev.y + (new.position.y - old.position.y) * (new.position.y - result.position.y))/Float(result.count)*/
        
        // FIXME: This implementation just averages
        return MapPoint(position: (position + other.position) * 0.5, stddev: float2(), startAngle: (startAngle + other.startAngle) / 2.0, endAngle: (endAngle + other.endAngle) / 2.0, count: count + other.count)
    }
    
    mutating func merge(with other: MapPoint) {
        self = merged(with: other)
    }
    
    // Returns a matrix that transforms new points to the coordinate space of from points
    static func transform(between: [(from: MapPoint, to: MapPoint)]) -> float4x4 {
        
        let existingPointsXY = between.map { $0.from.position.xy }
        let newPointsXY = between.map { $0.to.position.xy }
        
        let existingPointsCenter = existingPointsXY.average
        let newPointsCenter = newPointsXY.average
        
        let centeredExistingPoints = existingPointsXY.map { $0 - existingPointsCenter }
        let centeredNewPoints = newPointsXY.map { $0 - newPointsCenter }
        
        let w = zip(centeredExistingPoints, centeredNewPoints).reduce(float2x2()) { $0 + outer($1.0, $1.1) }
        
        let (u, _, vTranspose) = w.svd
        
        let rotation = u * vTranspose
        let translation = existingPointsCenter - rotation * newPointsCenter
        
        return float4x4(translation: translation) * float4x4(rotation: rotation)
    }
}

struct VectorMapConnection: Hashable {
    
    let point1: Int
    let point2: Int
    
    let index: Int
    
    var hashValue: Int {
        return point1 ^ point2
    }
    
    static func ==(lhs: VectorMapConnection, rhs: VectorMapConnection) -> Bool {
        return (lhs.point1 == rhs.point1 && lhs.point2 == rhs.point2) || (lhs.point1 == rhs.point2 && lhs.point2 == rhs.point1)
    }
}
