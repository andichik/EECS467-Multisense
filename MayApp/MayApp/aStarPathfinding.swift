//
//  aStarPathfinding.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/02/22.
//  Copyright © 2017 University of Michigan. All rights reserved.
//
//  Heavily Based on David Kopec's (davecom) astar example and priority queue library

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

func backtrack<T>(_ dest: Node<T>) -> [T] {
    var sol: [T] = []
    // var sol: [T]() // Shorter Hand
    
    var node = dest
    
    while (node.parent != nil) {
        sol.append(node.pos)
        node = node.parent!
    }
    
    sol.append(node.pos)
    
    return sol
}

// TODO
func findH<T>(pos: T) -> float {
    
}

// TODO
func findNext<T>(pos: T, thres: float) -> [T] {
    
}

// start: intial position
// isDest: fucntion that checks whether a pos is the destination
// findNext: function returns next set of successor nodes
// findH: funtion returns heuristic (estimate) of passesd node
// thres: threshold that determines whether a texile is off-limit
public func astar<T: Hashable>(start: T, isDest: (T) -> Bool, findNext: (T, float) -> [T], findH: (T) -> Float, map: MTLTexture, thres: Float) {
    var unexplored = PriorityQueue(ascending: true, startingValues: [Node(state: start, parent: nil, cost: 0, heuristic: findH(start)])
    var explored = Dictionary<T, Float>()
    explored[start] = 0
    var numNodeSearched: Int = 0
    
    while !unexplored.isEmpty {
        numNodeSearched += 1
        let currentNode = unexplored.pop()
        let currentPos = currentNode.pos
        
        if isDest(currentPos) {
            return backtrack(currentNode)
        }
        
        for child in findNext(currentPos, thres) {
            let newcost = currentNode.cost + 1 // +1 due to being a grid map
            if (explored[child] == nil) || (explored[child] > newcost) {
                explored[child] = newcost
                unexplored.push(Node(state: child, parent: currentNode, cost: newcost, heuristic: findH(child)))
            }
        }
    }
}

