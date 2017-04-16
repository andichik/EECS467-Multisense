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
    let distancesBuffer: TypedMetalBuffer<Float>
    
    var connections = Set<VectorMapConnection>()
    
    let pointRenderPipeline: MTLRenderPipelineState
    let connectionRenderPipeline: MTLRenderPipelineState
    
    let pointRenderIndices: SectorIndices
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        // Make buffers
        
        pointBuffer = TypedMetalBuffer(device: library.device)
        connectionBuffer = TypedMetalBuffer(device: library.device)
        distancesBuffer = TypedMetalBuffer(device: library.device)
        
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
    
    /*func mergePoints(_ points: [MapPoint]) {
        
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
    }*/
    
    func assignments(for points: [MapPoint]) -> [Int?] {
        
        var best: (assignments: [Int?], count: Int)?
        
        func tryTransform(_ transform: float4x4) {
            
            let correctedPoints = points.map { $0.applying(transform: transform) }
            
            let assignments: [Int?] = correctedPoints.map { correctedPoint in
                
                if let closest = pointBuffer.closest({ correctedPoint.distance(to: $0) }), closest.distance < 0.1 {
                    return closest.index
                } else {
                    return nil
                }
            }
            
            let assignmentCount = assignments.reduce(0) { $0 + ($1 == nil ? 0 : 1) }
            
            guard let definiteBest = best else {
                best = (assignments, assignmentCount)
                return
            }
            
            if definiteBest.count < assignmentCount {
                best = (assignments, assignmentCount)
            }
        }
        
        // For every distance in new points
        points.forEachPair { point1, point2 in
            
            let newDistance = point1.distance(to: point2)
            
            // For every similar old distance
            for (index, oldDistance) in distancesBuffer.enumerated() where abs(newDistance - oldDistance) < 0.1 {
                
                let pointIndices = connectionBuffer[index]
                
                let oldPoint1 = pointBuffer[Int(pointIndices.0)]
                let oldPoint2 = pointBuffer[Int(pointIndices.1)]
                
                let transform1 = MapPoint.transform(between: [(oldPoint1, point1), (oldPoint2, point2)])
                let transform2 = MapPoint.transform(between: [(oldPoint1, point2), (oldPoint2, point1)])
                
                tryTransform(transform1)
                tryTransform(transform2)
                
                // TODO: Keep track of best transform
            }
        }
        
        return best!.assignments
    }
    
    func mergePoints(_ points: [MapPoint], assignments: [Int?]) {
        
        // Keep track of new point indices in pointBuffer
        var assignedIndices = Set<Int>()
        
        // Merge and append points
        for (point, assignment) in zip(points, assignments) {
            
            if let assignment = assignment {
                
                assignedIndices.insert(assignment)
                pointBuffer[assignment].merge(with: point)
                
            } else {
                
                assignedIndices.insert(pointBuffer.count)
                pointBuffer.append(point)
            }
        }
        
        // Add connections
        assignedIndices.forEachPair { point1, point2 in
            
            let connection = VectorMapConnection(point1: point1, point2: point2, index: connectionBuffer.count)
            
            let (inserted, existingConnection) = connections.insert(connection)
            
            if inserted {
                
                connectionBuffer.append((UInt16(point1), UInt16(point2)))
                distancesBuffer.append(pointBuffer[point1].distance(to: pointBuffer[point2]))
                
            } else {
                
                distancesBuffer[existingConnection.index] = pointBuffer[point1].distance(to: pointBuffer[point2])
            }
        }
    }
    
    func correctAndMergePoints(_ points: [MapPoint]) -> float4x4 {
        
        guard !pointBuffer.isEmpty else {
            
            mergePoints(points, assignments: Array<Int?>(repeating: nil, count: points.count))
            
            return float4x4(diagonal: float4(1.0))
        }
        
        // Make registrations
        let assignments = self.assignments(for: points)
        
        // Make an array of paired assignments
        let pointAssignments: [(MapPoint, MapPoint)] = assignments.enumerated().flatMap { newPointIndex, assignmentIndex in
            
            guard let assignmentIndex = assignmentIndex else {
                return nil
            }
            
            return (pointBuffer[assignmentIndex], points[newPointIndex])
        }
        
        // Find best transform between point sets
        // The transform from new to existing points
        // This transform moves points into the coordinate space of the map
        // Therefore this transform also localizes the robot
        let transform = MapPoint.transform(between: pointAssignments)
        
        // Correct points
        let correctedPoints = points.map { $0.applying(transform: transform) }
        
        // Merge points
        mergePoints(correctedPoints, assignments: assignments)
        
        return transform
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
