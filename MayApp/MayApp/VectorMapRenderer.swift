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
    
    let pointBuffer: TypedMetalBuffer<RenderMapPoint>
    let connectionBuffer: TypedMetalBuffer<(UInt16, UInt16)>
    
    var pointDictionary = [UUID: MapPoint]()
    var indicesByPointIDs = [UUID: Int]()
    
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
    
    func assignments(for points: [MapPoint]) -> [UUID?]? {
        
        var best: (assignments: [UUID?], transformMagnitude: Float)?
        
        func tryTransform(_ transform: float4x4) {
            
            let transformMagnitude = transform.magnitude
            
            guard transformMagnitude <= 0.1 else {
                return
            }
            
            let correctedPoints = points.map { $0.applying(transform: transform) }
            
            let assignments: [UUID?] = correctedPoints.map { correctedPoint in
                
                if let closest = pointDictionary.closest({ correctedPoint.distance(to: $0.value) }), closest.distance < 0.1 {
                    return closest.element.key
                } else {
                    return nil
                }
            }
            
            let assignmentCount = assignments.reduce(0) { $0 + ($1 == nil ? 0 : 1) }
            
            // Only take assignments that match at least three points
            guard assignmentCount >= 2 else {
                return
            }
            
            guard let definiteBest = best else {
                best = (assignments, transformMagnitude)
                return
            }
            
            if transformMagnitude < definiteBest.transformMagnitude {
                best = (assignments, transformMagnitude)
            }
        }
        
        // For every distance in new points
        points.forEachPair { point1, point2 in
            
            let newDistance = point1.distance(to: point2)
            
            // For every similar old distance
            for connection in connections where abs(newDistance - connection.distance) < 0.1 {
                
                let oldPoint1 = pointDictionary[connection.id1]!
                let oldPoint2 = pointDictionary[connection.id2]!
                
                let transform1 = MapPoint.transform(between: [(oldPoint1, point1), (oldPoint2, point2)])
                let transform2 = MapPoint.transform(between: [(oldPoint1, point2), (oldPoint2, point1)])
                
                tryTransform(transform1)
                tryTransform(transform2)
                
                // TODO: Keep track of best transform
            }
        }
        
        if let best = best, best.transformMagnitude > 1.0 {
            print("Giant transform!!!!")
        }
        
        return best?.assignments
    }
    
    func mergePoints(_ points: [MapPoint], assignments: [UUID?]) {
        
        // Keep track of new point ids
        var assignedIDs = Set<UUID>()
        
        // Merge and append points
        for (point, assignment) in zip(points, assignments) {
            
            if let assignment = assignment {
                
                assignedIDs.insert(assignment)
                pointDictionary[assignment]!.merge(with: point)
                
                let index = indicesByPointIDs[assignment]!
                pointBuffer[index] = pointDictionary[assignment]!.render
                
            } else {
                
                let id = point.id
                
                assignedIDs.insert(id)
                pointDictionary[id] = point
                
                let index = pointBuffer.count
                indicesByPointIDs[id] = index
                pointBuffer.append(point.render)
            }
        }
        
        // Add connections
        assignedIDs.forEachPair { id1, id2 in
            
            let distance = pointDictionary[id1]!.distance(to: pointDictionary[id2]!)
            
            let connection = VectorMapConnection(id1: id1, id2: id2, index: connectionBuffer.count, distance: distance)
            
            let oldConnection = connections.update(with: connection)
            
            if oldConnection == nil {
                
                connectionBuffer.append((UInt16(indicesByPointIDs[id1]!), UInt16(indicesByPointIDs[id2]!)))
            }
        }
    }
    
    func correctAndMergePoints(_ points: [MapPoint]) -> float4x4 {
        
        guard !pointBuffer.isEmpty else {
            
            mergePoints(points, assignments: Array<UUID?>(repeating: nil, count: points.count))
            
            return float4x4(diagonal: float4(1.0))
        }
        
        // Make registrations
        guard let assignments = self.assignments(for: points) else {
            
            return float4x4(diagonal: float4(1.0))
        }
        
        // Make an array of paired assignments
        let pointAssignments: [(MapPoint, MapPoint)] = zip(assignments, points).flatMap { assignment, point in
            
            guard let assignment = assignment else {
                return nil
            }
            
            return (pointDictionary[assignment]!, point)
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
        
        pointDictionary.removeAll()
        indicesByPointIDs.removeAll()
        
        connections.removeAll()
    }
}
