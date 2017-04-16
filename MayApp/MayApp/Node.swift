//
//  Node.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/04/05.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

import Foundation
import simd

public class Node<T>: Comparable, Hashable {
    let pos: T
    let parent: Node<T>?
    let cost: Float
    let h: Float
    init(pos: T, parent: Node<T>?, cost: Float, h: Float) {
        self.pos = pos
        self.parent = parent
        self.cost = cost
        self.h = h
    }
    public var hashValue: Int { return (Int) (cost + h) }
    
    public static func < <T>(lhs: Node<T>, rhs: Node<T>) -> Bool {
        return (lhs.cost + lhs.h) < (rhs.cost + rhs.h)
    }
    
    public static func == <T>(lhs: Node<T>, rhs: Node<T>) -> Bool {
        return lhs === rhs
    }
}
