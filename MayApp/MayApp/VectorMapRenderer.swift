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
                pointBuffer[match.index].merge(with: newPoint)
                
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
    
    func correctAndMergePoints(_ points: [MapPoint]) -> float4x4 {
        
        guard !pointBuffer.isEmpty else {
            mergePoints(points)
            return float4x4(diagonal: float4(1.0))
        }
        
        // Make registrations
        
        // FIRST JUST DO NEAREST NEIGHBOR FOR EACH POINT
        // For each new point, find closest point in oldPoints and save the assignment
        let assignments: [(index: Int, existingPoint: MapPoint, newPoint: MapPoint)] = points.flatMap { point in
            
            let closest = pointBuffer.enumerated().reduce(nil) { result, next -> (index: Int, point: MapPoint, distance: Float)? in
                
                let distance = point.distance(to: next.element)
                
                guard let result = result else {
                    return (next.offset, next.element, distance)
                }
                
                if distance < result.distance {
                    return (next.offset, next.element, distance)
                } else {
                    return result
                }
            }
            
            if let closest = closest {
                return (closest.index, closest.point, point)
            } else {
                return nil
            }
        }
        
        // Find best transform between point sets
        let existingPointsXY = assignments.map { $0.existingPoint.position.xy }
        let newPointsXY = assignments.map { $0.newPoint.position.xy }
        
        let existingPointsCenter = existingPointsXY.average
        let newPointsCenter = newPointsXY.average
        
        let centeredExistingPoints = existingPointsXY.map { $0 - existingPointsCenter }
        let centeredNewPoints = newPointsXY.map { $0 - newPointsCenter }
        
        let w = zip(centeredExistingPoints, centeredNewPoints).reduce(float2x2()) { $0 + outer($1.0, $1.1) }
        
        let (u, _, vTranspose) = w.svd
        
        let rotation = u * vTranspose
        let translation = existingPointsCenter - rotation * newPointsCenter
        
        // The transform from new to existing points
        // This transform moves points into the coordinate space of the map
        // Therefore this transform also localizes the robot
        let transform = float4x4(translation: translation) * float4x4(rotation: rotation)
        
        // Merge corrected points with assignments
        /*for (index, existingPoint, newPoint) in assignments {
            pointBuffer[index] = mergePoint(new: newPoint.applying(transform: transform), old: existingPoint)
        }*/
        
        let correctedPoints = points.map { $0.applying(transform: transform) }
        mergePoints(correctedPoints)
        
        // TODO: add a distance threshold to assignments (and possibily other features)
        // Iterate once, a few times, or until convergence
        
        return transform
        
        // BETTER ALGORITHM
        // Find all distances between points passed in
        //let distances = points.po
        
        // For every pair of points in points passed in
        // Take distance
        
        // Find distances in array of distances of all points (nearby in future) that are within a threshold of our distance
        
        // Change this to return acrual correction matrix
        //return float4x4(diagonal: float4(1.0))
    }
    
    func renderPoints(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        guard pointBuffer.count > 0 else { return }
        
        commandEncoder.setRenderPipelineState(pointRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        var uniforms = MapPointVertexUniforms(projectionMatrix: projectionMatrix.cmatrix, outerVertexCount: ushort(pointRenderIndices.outerVertexCount))
        
        commandEncoder.setVertexBuffer(pointBuffer.metalBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        var color = float4(0.0, 0.5, 1.0, 1.0)
        
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
        
        var color = float4(0.0, 0.5, 1.0, 1.0)
        
        commandEncoder.setFragmentBytes(&color, length: MemoryLayout.stride(ofValue: color), at: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .line, indexCount: 2 * connectionBuffer.count, indexType: .uint16, indexBuffer: connectionBuffer.metalBuffer, indexBufferOffset: 0)
    }
    
    func reset() {
        
        pointBuffer.removeAll()
        connectionBuffer.removeAll()
        
        connections.removeAll()
    }
}
