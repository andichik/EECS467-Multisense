//
//  Node.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/04/05.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

import Foundation
import simd

public class Node: Comparable, Hashable {
    let pos: uint2
    var parent: Node?
    var cost: Float
    let h: Float
    init(pos: uint2, parent: Node?, cost: Float, h: Float) {
        self.pos = pos
        self.parent = parent
        self.cost = cost
        self.h = h
    }
    
    enum Direction{
        case north
        case east
        case south
        case west
    }
    
    public var hashValue: Int {
        var hash: UInt32 = 17
        hash = (hash + pos.x) << 5 - (hash + pos.x)
        hash = (hash + pos.y) << 5 - (hash + pos.y)
        return Int(hash)
    }
    
    public static func < (lhs: Node, rhs: Node) -> Bool {
        return (lhs.cost + lhs.h) < (rhs.cost + rhs.h)
    }
    
    public static func == (lhs: Node, rhs: Node) -> Bool {
        return lhs === rhs
    }
}
