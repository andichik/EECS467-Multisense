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

public final class AStar {
    
    var map: [[Float]] = []
    // let dest: uint2
    
    init(map: MTLBuffer, dimension: Int, length: Int) {
        
        self.map = Array(repeating: Array(repeating: 0, count: dimension), count: dimension)
        
        for i in 0...(dimension - 1) {
            for j in 0...(dimension - 1) {
                self.map[i][j] = map.contents().load(fromByteOffset: (4 * dimension * i) + (4 * j), as: Float.self)
            }
        }
    }
    
    enum Direction {
        case North, South, East, West
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
    func findH<T>(pos: T) -> Float {
        return 0.0
    }
    
    // TODO
    func findNext<T>(pos: T, thres: Float) -> [T] {
        return [pos]
    }
    
    // start: intial position
    // isDest: fucntion that checks whether a pos is the destination
    // findNext: function returns next set of successor nodes
    // findH: funtion returns heuristic (estimate) of passesd node
    // thres: threshold that determines whether a texile is off-limit
    public func run<T: Hashable>(start: T, isDest: (T) -> Bool, findNext: (T, Float) -> [T], findH: (T) -> Float, map: MTLTexture, thres: Float) -> [T]? {
        
        var unexplored = PriorityQueue(ascending: true, startingValues: [Node(pos: start, parent: nil, cost: 0, h: findH(start))])
        
        var explored = Dictionary<T, Float>()
        explored[start] = 0
        var numNodeSearched: Int = 0
        
        while !unexplored.isEmpty {
            numNodeSearched += 1
            let currentNode = unexplored.pop()!
            let currentPos = currentNode.pos
            
            if isDest(currentPos) {
                return backtrack(currentNode)
            }
            
            for child in findNext(currentPos, thres) {
                let newcost = currentNode.cost + 1 // +1 due to being a grid map
                if (explored[child] == nil) || (explored[child]! > newcost) {
                    explored[child] = newcost
                    unexplored.push(Node(pos: child, parent: currentNode, cost: newcost, h: findH(child)))
                }
            }
        }
        
        return nil
    }
    
}



