//
//  VectorMapRenderer.swift
//  MayApp
//
//  Created by Russell Ladd on 4/2/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal

public final class VectorMapRenderer {
    
    static let points = 1024
    
    var pointsCount = 0
    let mapPointBuffer: MTLBuffer
    
    let pointRenderPipeline: MTLRenderPipelineState
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        // Make curvature buffer
        
        mapPointBuffer = library.device.makeBuffer(length: VectorMapRenderer.points * MemoryLayout<MapPoint>.stride, options: [])
        
        // Make corners pipeline
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "mapPointVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "cornersFragment")
        
        pointRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }
    
    func mergePoints(_ points: [MapPoint]) {

        for newPoint in points {
            
            // find nearest already-logged point
            let pointer = self.mapPointBuffer.contents().assumingMemoryBound(to: MapPoint.self)
            let buffer = UnsafeMutableBufferPointer(start: pointer, count: pointsCount)
            
            var matchedPoint: MapPoint? = nil
            var distance: Float = .infinity
            
            for oldPoint in buffer {
                let dist = sqrt(pow((newPoint.position.x - oldPoint.position.x),2) + pow((oldPoint.position.y - oldPoint.position.y), 2))
                if dist < distance {
                    distance = dist
                    matchedPoint = oldPoint
                }
            }
            
            // merge (if euclidean distance < 5cm, then merge, otherwise add)
            if distance < 0.05 {
                if var match = matchedPoint {
                    match = mergePoint(new: newPoint, old: match)
                }
                else {
                    // this should be impossible - distance reduced to 5 with no valid point?
                    assert(false)
                }
            }
            else {
                pointsCount += 1
                let mutableBuffer = UnsafeMutableBufferPointer(start: pointer, count: pointsCount + 1)
                
                mutableBuffer[pointsCount - 1] = newPoint
            }
        }
    }
    
    func mergePoint(new: MapPoint, old: MapPoint) -> MapPoint {
        var result = old
        
        // update normal distribution's means, stddev (on distance)
        // http://math.stackexchange.com/questions/250927/iteratively-updating-a-normal-distribution
        result.position.x = old.position.x + (new.position.x - old.position.x)/Float(old.count)
        result.position.y = old.position.y + (new.position.y - old.position.y)/Float(old.count)
        
        result.count += 1
        
        result.stddev.x = sqrt(old.stddev.x + (new.position.x - old.position.x) * (new.position.x - result.position.x)/Float(result.count))
        result.stddev.y = sqrt(old.stddev.y + (new.position.y - old.position.y) * (new.position.y - result.position.y))/Float(result.count)
        
        return result
    }
    
    func renderPoints(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        guard pointsCount > 0 else { return }
        
        commandEncoder.setRenderPipelineState(pointRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        var uniforms = MapPointVertexUniforms(projectionMatrix: projectionMatrix.cmatrix, pointSize: 12.0)
        
        commandEncoder.setVertexBuffer(mapPointBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        var color = float4(1.0, 0.0, 0.0, 1.0)
        
        commandEncoder.setFragmentBytes(&color, length: MemoryLayout.stride(ofValue: color), at: 0)
        
        commandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: pointsCount)
    }
}
