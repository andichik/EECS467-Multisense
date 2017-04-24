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
    
    struct BestH {
        var h: Float
        var position: uint2
    }
    
    var map: [[WeightedNode]] = []
//    var map: [[Float]] = []
    var dimension: UInt32
    var destination: uint2?
    var bestH: BestH
    
    init(dimension: Int) {
        
        self.map = Array(repeating: Array(repeating: WeightedNode(node: nil, weight: 0), count: dimension), count: dimension)
        
//        for i in 0...(dimension - 1) {
//            for j in 0...(dimension - 1) {
//                self.map[j][i].weight = map.contents().load(fromByteOffset: (MemoryLayout<Float>.stride * dimension * i) + (MemoryLayout<Float>.stride * j), as: Float.self)
//                /*if(self.map[i][j].weight > 0.5) {
//                    print(i,j,self.map[i][j].weight)
//                }*/
//                
//            }
//        }

        self.dimension = UInt32(dimension)
        self.bestH = BestH(h: Float(2 * self.dimension), position: uint2(0,0))
        
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
        
        pathBuffer.append(float4((Float(dest.pos.x) / Float(dimension) - 0.5) * PathMapRenderer.meters,
                                 (0.5 - Float(dest.pos.y) / Float(dimension)) * PathMapRenderer.meters,
                                 0.0,
                                 1.0))
        
        var node: Node? = dest
        
        while let n = node {
            
            pathBuffer.append(float4((Float(n.pos.x) / Float(dimension) - 0.5) * PathMapRenderer.meters,
                                     (0.5 - Float(n.pos.y) / Float(dimension)) * PathMapRenderer.meters,
                                     0.0,
                                     1.0))
            
            node = n.parent
        }
    }
    
    func findH(pos: uint2) -> Float {
        let x2 = (pos.x > destination!.x) ? powf(Float(pos.x - destination!.x),2.0) : powf(Float(destination!.x - pos.x),2.0)
        let y2 = (pos.y > destination!.y) ? powf(Float(pos.y - destination!.y),2.0) : powf(Float(destination!.y - pos.y),2.0)
        let H = sqrtf(x2 + y2)
        if(bestH.h > H) {
            bestH.h = H
            bestH.position = pos
        }
        return H
    }
    
    func findNext(pos: uint2, radius: UInt32) -> [uint2] {
        var children: [uint2] = []
        if(pos.x + radius) < dimension {
            if(map[Int(pos.x + radius)][Int(pos.y)].weight <= 0.0) {
                children.append(uint2(pos.x + radius,pos.y))
            }
        }
        if(pos.y + radius) < dimension {
            if(map[Int(pos.x)][Int(pos.y + radius)].weight <= 0.0) {
                children.append(uint2(pos.x,pos.y + radius))
            }
        }
        if(pos.x != 0) {
            if(map[Int(pos.x - radius)][Int(pos.y)].weight <= 0.0) {
                children.append(uint2(pos.x - radius, pos.y))
            }
        }
        if(pos.y != 0) {
            if(map[Int(pos.x)][Int(pos.y - radius)].weight <= 0.0) {
                children.append(uint2(pos.x, pos.y - radius))
            }
        }
        return children
    }
    
    func isDest(pos: uint2) -> Bool {
        return (pos.x == destination!.x) && (pos.y == destination!.y)
    }
    
    // start: intial position
    // isDest: fucntion that checks whether a pos is the destination
    // findNext: function returns next set of successor nodes
    // findH: funtion returns heuristic (estimate) of passesd node
    // thres: threshold that determines whether a texile is off-limit
    // returns true if a path is found, false otherwise
    public func run(start: uint2, thres: Float, pathBuffer: TypedMetalBuffer<float4>) -> Bool {
        
        let startTime = Date()
        let startNode = Node(pos: start, parent: nil, cost: 0, h: findH(pos: start))
        var unexplored = PriorityQueue(ascending: true, startingValues: [startNode])
        
//        var explored = Dictionary<Node, Float>()
        map[Int(start.x)][Int(start.y)].node = startNode
        var numNodeSearched: Int = 0
        
        while ((Date().timeIntervalSince(startTime) < PathRenderer.maxDuration!) && !unexplored.isEmpty) {
            numNodeSearched += 1
            let currentNode = unexplored.pop()!
            let currentPos = currentNode.pos
//            print(currentPos)
            
            if isDest(pos: currentPos) {
                backtrack(dest: currentNode, pathBuffer: pathBuffer)
                return true
            }
            
            let newcost = currentNode.cost + 1 // +1 due to being a grid map
            for child in findNext(pos: currentPos, radius: 1) {
                
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
        print("@@@ A* Run took: ", Date().timeIntervalSince(startTime))
        backtrack(dest: map[Int(bestH.position.x)][Int(bestH.position.y)].node!, pathBuffer: pathBuffer)
        return false
    }
    
    public func loadMap(buffer: MTLBuffer) {
        
        let dimensionInt: Int = Int(dimension)
        
        let startTime = Date()
        for i in 0...(dimensionInt - 1) {
            for j in 0...(dimensionInt - 1) {
                map[j][i].weight = buffer.contents().load(fromByteOffset: (MemoryLayout<Float>.stride * dimensionInt * i) + (MemoryLayout<Float>.stride * j), as: Float.self)
                map[j][i].node = nil
                
            }
        }
        print("@@@ Load Map took: ", Date().timeIntervalSince(startTime))
        self.bestH = BestH(h: Float(2 * self.dimension), position: uint2(0,0))
    }
    
    public func loadDestination(destination: uint2) {
        self.destination = destination
    }
}



