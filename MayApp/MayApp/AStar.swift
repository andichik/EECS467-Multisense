//
//  AStar.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/02/22.
//  Copyright © 2017 University of Michigan. All rights reserved.
//
//  Heavily Based on David Kopec's (davecom) astar example and priority queue library

import Foundation
import Metal
import simd
#if os(iOS)
    import UIKit
#endif

public final class AStar {
    
    struct WeightedNode {
        var node: Node? = nil
        var weight: Float
    }
    
    var map: [[WeightedNode]] = []
//    var map: [[Float]] = []
    var dimension: UInt32
    var destination: uint2
    
    init(map: MTLBuffer, dimension: Int, destination: float2) {
        
        self.map = Array(repeating: Array(repeating: WeightedNode(node: nil, weight: 0), count: dimension), count: dimension)
        
        for i in 0...(dimension - 1) {
            for j in 0...(dimension - 1) {
                self.map[j][i].weight = map.contents().load(fromByteOffset: (MemoryLayout<Float>.stride * dimension * i) + (MemoryLayout<Float>.stride * j), as: Float.self)
                /*if(self.map[i][j].weight > 0.5) {
                    print(i,j,self.map[i][j].weight)
                }*/
                
            }
        }
        self.destination = uint2(UInt32(destination.x * Float(dimension)), UInt32(destination.y * Float(dimension)))
        self.dimension = UInt32(dimension)
        
//        var ascii = ""
//        
//        for row in self.map {
//            ascii += (String(row.map { $0.weight <= 0.0 ? " " : "X"}) + "\n")
//        }
//        
//        UIPasteboard.general.setValue(ascii, forPasteboardType: UIPasteboardTypeAutomatic)
    }
    
    func backtrack(dest: Node, pathBuffer: TypedMetalBuffer<float4>) {
        
        pathBuffer.removeAll()
        
        pathBuffer.append(float4((Float(dest.pos.x) / Float(dimension) - 0.5) * Map.meters,
                                 (0.5 - Float(dest.pos.y) / Float(dimension)) * Map.meters,
                                 0.0,
                                 1.0))
        
        var node: Node? = dest
        
        while let n = node {
            
            pathBuffer.append(float4((Float(n.pos.x) / Float(dimension) - 0.5) * Map.meters,
                                     (0.5 - Float(n.pos.y) / Float(dimension)) * Map.meters,
                                     0.0,
                                     1.0))
            
            node = n.parent
        }
    }
    
    func findH(pos: uint2) -> Float {
        let x2 = (pos.x > destination.x) ? powf(Float(pos.x - destination.x),2.0) : powf(Float(destination.x - pos.x),2.0)
        let y2 = (pos.y > destination.y) ? powf(Float(pos.y - destination.y),2.0) : powf(Float(destination.y - pos.y),2.0)
        return sqrtf(x2 + y2)
    }
    
    func findNext(pos: uint2, thres: Float) -> [uint2] {
        var children: [uint2] = []
        if(pos.x + 1) < dimension {
            if(map[Int(pos.x + 1)][Int(pos.y)].weight <= 0.0) {
                children.append(uint2(pos.x + 1,pos.y))
            }
        }
        if(pos.y + 1) < dimension {
            if(map[Int(pos.x)][Int(pos.y + 1)].weight <= 0.0) {
                children.append(uint2(pos.x,pos.y + 1))
            }
        }
        if(pos.x != 0) {
            if(map[Int(pos.x - 1)][Int(pos.y)].weight <= 0.0) {
                children.append(uint2(pos.x - 1, pos.y))
            }
        }
        if(pos.y != 0) {
            if(map[Int(pos.x)][Int(pos.y - 1)].weight <= 0.0) {
                children.append(uint2(pos.x, pos.y - 1))
            }
        }
        return children
    }
    
    func isDest(pos: uint2) -> Bool {
        return (pos.x == destination.x) && (pos.y == destination.y)
    }
    
    // start: intial position
    // isDest: fucntion that checks whether a pos is the destination
    // findNext: function returns next set of successor nodes
    // findH: funtion returns heuristic (estimate) of passesd node
    // thres: threshold that determines whether a texile is off-limit
    // returns true if a path is found, false otherwise
    public func run(start: uint2, thres: Float, pathBuffer: TypedMetalBuffer<float4>) -> Bool {
        
        let startNode = Node(pos: start, parent: nil, cost: 0, h: findH(pos: start))
        var unexplored = PriorityQueue(ascending: true, startingValues: [startNode])
        
//        var explored = Dictionary<Node, Float>()
        map[Int(start.x)][Int(start.y)].node = startNode
        var numNodeSearched: Int = 0
        
        while !unexplored.isEmpty {
            numNodeSearched += 1
            let currentNode = unexplored.pop()!
            let currentPos = currentNode.pos
//            print(currentPos)
            
            if isDest(pos: currentPos) {
                backtrack(dest: currentNode, pathBuffer: pathBuffer)
                return true
            }
            
            let newcost = currentNode.cost + 1 // +1 due to being a grid map
            for child in findNext(pos: currentPos, thres: thres) {
                
                if (map[Int(child.x)][Int(child.y)].node == nil) {
                    let newNode = Node(pos: child, parent: currentNode, cost: newcost, h: findH(pos: child))
                    map[Int(child.x)][Int(child.y)].node = newNode
                    unexplored.push(newNode)
                }
                else if (map[Int(child.x)][Int(child.y)].node!.cost > newcost) {
                    
                    unexplored.remove(map[Int(child.x)][Int(child.y)].node!)
                    map[Int(child.x)][Int(child.y)].node?.cost = newcost
                    map[Int(child.x)][Int(child.y)].node?.parent = currentNode
                    unexplored.push(map[Int(child.x)][Int(child.y)].node!)
                }
            }
        }
    
        return false
    }
    
}



