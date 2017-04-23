//
//  VectorMapConnection.swift
//  MayApp
//
//  Created by Russell Ladd on 4/3/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import simd

struct MapPoint {
    
    var id: UUID
    var position: float4
    
    // The start and end angles sweep counterclockwise through free space
    // Either may be NAN to indicate unknown
    // If both are NAN, the point is an arbitrary marker that shouldn't be used for matching
    
    var startAngle: Float           // angle in world space with occupied space on right and free space on left
    var endAngle: Float             // angle in world space with occupied space on left and free space on right
    
    func distance(to other: MapPoint) -> Float {
        return simd.distance(float2(position.x, position.y), float2(other.position.x, other.position.y))
    }
    
    func applying(transform: float4x4) -> MapPoint {
        // FIXME: start angle and end angle need to rotate too
        // Change them to be "vectors" float4 with last component 0.0 so we can just multiply by transform
        let angle = atan2(transform[0, 1], transform[0, 0])
        return MapPoint(id: id, position: transform * position, startAngle: startAngle + angle, endAngle: endAngle + angle)
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
        // FIXME: Except it doesn't average angles correctly!
        
        return MapPoint(id: id, position: 0.5 * (position + other.position), startAngle: startAngle.anglularAverage(with: other.startAngle), endAngle: endAngle.anglularAverage(with: other.endAngle))
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
    
    var render: RenderMapPoint {
        return RenderMapPoint(position: position, startAngle: startAngle, endAngle: endAngle)
    }
}

struct VectorMapConnection: Hashable {
    
    let id1: UUID
    let id2: UUID
    
    let index: Int
    
    let distance: Float
    
    var hashValue: Int {
        return id1.hashValue ^ id2.hashValue
    }
    
    static func ==(lhs: VectorMapConnection, rhs: VectorMapConnection) -> Bool {
        return (lhs.id1 == rhs.id1 && lhs.id2 == rhs.id2) || (lhs.id1 == rhs.id2 && lhs.id2 == rhs.id1)
    }
}
