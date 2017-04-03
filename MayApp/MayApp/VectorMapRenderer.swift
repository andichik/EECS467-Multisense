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
    
    let pointBuffer: TypedMetalBuffer<MapPoint>
    
    let pointRenderPipeline: MTLRenderPipelineState
    
    let pointRenderIndices: SectorIndices
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        // Make curvature buffer
        
        pointBuffer = TypedMetalBuffer(device: library.device)
        
        // Make corners pipeline
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "mapPointVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "cornersFragment")
        
        pointRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        pointRenderIndices = SectorIndices(device: library.device, outerVertexCount: 16)
    }
    
    func mergePoints(_ points: [MapPoint]) {

        for newPoint in points {
            
            // find nearest already-logged point
            var bestMatch: (index: Int, point: MapPoint, distance: Float)? = nil
            
            for (index, oldPoint) in pointBuffer.enumerated() {
                
                let distance = simd.distance(float2(oldPoint.position.x, oldPoint.position.y), float2(newPoint.position.x, newPoint.position.y))
                
                guard let match = bestMatch else {
                    bestMatch = (index, oldPoint, distance)
                    continue
                }
                
                if distance < match.distance {
                    bestMatch = (index, oldPoint, distance)
                }
            }
            
            // merge (if euclidean distance < 5cm, then merge, otherwise add)
            if let match = bestMatch, match.distance < 0.1 {
                
                pointBuffer[match.index] = mergePoint(new: newPoint, old: match.point)
                
            } else {
                
                pointBuffer.append(newPoint)
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
        
        guard pointBuffer.count > 0 else { return }
        
        commandEncoder.setRenderPipelineState(pointRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        var uniforms = MapPointVertexUniforms(projectionMatrix: projectionMatrix.cmatrix, outerVertexCount: ushort(pointRenderIndices.outerVertexCount))
        
        commandEncoder.setVertexBuffer(pointBuffer.metalBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        var color = float4(1.0, 0.0, 0.0, 1.0)
        
        commandEncoder.setFragmentBytes(&color, length: MemoryLayout.stride(ofValue: color), at: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: pointRenderIndices.indexCount, indexType: SectorIndices.indexType, indexBuffer: pointRenderIndices.indexBuffer, indexBufferOffset: 0, instanceCount: pointBuffer.count)
    }
}
