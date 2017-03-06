//
//  aStarPathfinding.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/02/22.
//  Copyright © 2017 University of Michigan. All rights reserved.
//
//  Heavily Based on David Kopec's astar example and priority queue library

import Foundation
import Metal
import simd

public class Node<T>: Comparable, Hashable {
    let pos: T
    let parent: Node?
    let cost: Float
    let h: Float
    init(pos: T, parent: Node, cost: Float, h: Float) {
        self.pos = pos
        self.parent = parent
        self.cost = cost
        self.h = h
    }
    public var hashValue: Int { return (Int) (cost + h) }
}

public func < <T>(lhs: Node<T>, rhs: Node<T>) -> Bool {
    return (lhs.cost + lhs.h) < (rhs.cost + rhs.h)
}

public func == <T>(lhs: Node<T>, rhs: Node<T>) -> Bool {
    return lhs === rhs
}

// start: intial position
// isDest: fucntion that checks whether a pos is the destination
// thres: threshold that determines whether a texile is off-limit
public func astar<T: Hashable>(start: T, isDest: (T) -> Bool, map: MTLTexture, thres: Float)

