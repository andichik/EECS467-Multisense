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
    let connectionBuffer: TypedMetalBuffer<(UInt16, UInt16)>
    
    var connections = Set<VectorMapConnection>()
    
    let pointRenderPipeline: MTLRenderPipelineState
    let connectionRenderPipeline: MTLRenderPipelineState
    
    let pointRenderIndices: SectorIndices
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        // Make buffers
        
        pointBuffer = TypedMetalBuffer(device: library.device)
        connectionBuffer = TypedMetalBuffer(device: library.device)
        
        // Make pipelines
        
        let pointRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        pointRenderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pointRenderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pointRenderPipelineDescriptor.vertexFunction = library.makeFunction(name: "mapPointVertex")!
        pointRenderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "cornersFragment")!
        
        pointRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: pointRenderPipelineDescriptor)
        
        let connectionRenderPipelineDescriptor = MTLRenderPipelineDescriptor()
        connectionRenderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        connectionRenderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        connectionRenderPipelineDescriptor.vertexFunction = library.makeFunction(name: "mapConnectionVertex")!
        connectionRenderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "cornersFragment")!
        
        connectionRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: connectionRenderPipelineDescriptor)
        
        // Make corner index buffer
        
        pointRenderIndices = SectorIndices(device: library.device, outerVertexCount: 16)
    }
    
    func mergePoints(_ points: [MapPoint]) {
        
        var assignedIndices = Set<UInt16>()

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
                
                assignedIndices.insert(UInt16(match.index))
                pointBuffer[match.index] = mergePoint(new: newPoint, old: match.point)
                
            } else {
                
                assignedIndices.insert(UInt16(pointBuffer.count))
                pointBuffer.append(newPoint)
            }
        }
        
        for setIndex in assignedIndices.indices {
            let point1 = assignedIndices[setIndex]
            for point2 in assignedIndices.prefix(upTo: setIndex) {
                
                if connections.insert(VectorMapConnection(point1: point1, point2: point2)).inserted {
                    connectionBuffer.append((point1, point2))
                }
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
    
    func renderConnections(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        guard connectionBuffer.count > 0 else { return }
        
        commandEncoder.setRenderPipelineState(connectionRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        var uniforms = MapConnectionVertexUniforms(projectionMatrix: projectionMatrix.cmatrix)
        
        commandEncoder.setVertexBuffer(pointBuffer.metalBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        var color = float4(1.0, 0.0, 0.0, 1.0)
        
        commandEncoder.setFragmentBytes(&color, length: MemoryLayout.stride(ofValue: color), at: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .line, indexCount: 2 * connectionBuffer.count, indexType: .uint16, indexBuffer: connectionBuffer.metalBuffer, indexBufferOffset: 0)
    }
    
    func reset() {
        
        pointBuffer.removeAll()
        connectionBuffer.removeAll()
        
        connections.removeAll()
    }
}
