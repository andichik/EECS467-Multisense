//
//  VectorMapConnection.swift
//  MayApp
//
//  Created by Russell Ladd on 4/3/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

struct VectorMapConnection: Hashable {
    
    let point1: UInt16
    let point2: UInt16
    
    var hashValue: Int {
        return Int(point1 ^ point2)
    }
    
    static func ==(lhs: VectorMapConnection, rhs: VectorMapConnection) -> Bool {
        return (lhs.point1 == rhs.point1 && lhs.point2 == rhs.point2) || (lhs.point1 == rhs.point2 && lhs.point2 == rhs.point1)
    }
}
