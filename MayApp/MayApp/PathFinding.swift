//
//  PathFinding.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/02/18.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

import Foundation
import Metal

public final class PathFinding {
    
    var library: MTLLibrary! = nil
    var commandQueue: MTLCommandQueue! = nil
    var commandBuffer: MTLCommandBuffer! = nil
    var computeCommandEncoder: MTLComputeCommandEncoder! = nil
    
    let pathFindingPipeline: MTLComputePipelineState
    
    
    init(library: MTLLibrary, mapTexture: MTLTexture) {
        
        self.library = library
        self.commandQueue = library.device.makeCommandQueue()
        self.commandBuffer = commandQueue.makeCommandBuffer()
        self.computeCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        
        let pathFindingFunction = library.makeFunction(name: "A_star")
        
        pathFindingPipeline = try! library.device.makeComputePipelineState(function: pathFindingFunction!)
        
        self.computeCommandEncoder.setComputePipelineState(self.pathFindingPipeline)
        
        computeCommandEncoder.setTexture(mapTexture, at: 0) // Danger map to read from
//        computeCommandEncoder.setTexture(
    }
    
    func find() {
        
    }
    
    
}
