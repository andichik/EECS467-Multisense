//
//  CurvatureRenderer.swift
//  MayApp
//
//  Created by Russell Ladd on 3/28/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal

public final class CurvatureRenderer {
    
    let curvatureBuffer: MTLBuffer
    
    let curvaturePipeline: MTLComputePipelineState
    
    let cornersBuffer: MTLBuffer
    var cornersBufferCount = 0
    let semaphore = DispatchSemaphore(value: 1)
    
    let cornersPipeline: MTLRenderPipelineState
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        // Make curvature buffer
        
        curvatureBuffer = library.device.makeBuffer(length: Laser.sampleCount * MemoryLayout<LaserPoint>.stride, options: [])
        
        // Make curvature pipeline
        
        let curvatureFunction = library.makeFunction(name: "computeCurvature")!
        
        curvaturePipeline = try! library.device.makeComputePipelineState(function: curvatureFunction)
        
        // Make corners buffer
        
        cornersBuffer = library.device.makeBuffer(length: Laser.sampleCount * MemoryLayout<LaserDistanceMesh.Index>.stride, options: [])
        
        // Make corners pipeline
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "cornersVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "cornersFragment")
        
        cornersPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
    }
    
    func calculateCurvature(commandBuffer: MTLCommandBuffer, laserDistancesBuffer: MTLBuffer, completionHandler: @escaping (_ mapPoints: [MapPoint]) -> Void) {
        
        self.semaphore.wait()
        
        // Make uniforms
        var uniforms = CurvatureUniforms(distanceCount: ushort(Laser.sampleCount), angleStart: Laser.angleStart, angleIncrement: Laser.angleIncrement, minimumDistance: Laser.minimumDistance, maximumDistance: Laser.maximumDistance)
        
        // Make thread execution sizes
        let threadgroupWidth = curvaturePipeline.maxTotalThreadsPerThreadgroup
        let threadsPerThreadGroup = MTLSize(width: threadgroupWidth, height: 1, depth: 1)
        
        let threadgroupsPerGrid = MTLSize(width: Int.divideRoundUp(Laser.sampleCount, threadgroupWidth), height: 1, depth: 1)
        
        // Make command encoder
        let commandEncoder = commandBuffer.makeComputeCommandEncoder()
        commandEncoder.label = "Calculate Curvature"
        
        commandEncoder.setComputePipelineState(curvaturePipeline)
        commandEncoder.setBuffer(laserDistancesBuffer, offset: 0, at: 0)
        commandEncoder.setBuffer(curvatureBuffer, offset: 0, at: 1)
        commandEncoder.setBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 2)
        
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        
        commandEncoder.endEncoding()
        
        commandBuffer.addCompletedHandler { _ in
            
            defer {
                self.semaphore.signal()
            }
            
            // Find corner indices
            
            let curvaturePointer = self.curvatureBuffer.contents().assumingMemoryBound(to: LaserPoint.self)
            let curvatureBuffer = UnsafeBufferPointer(start: curvaturePointer, count: Laser.sampleCount)
            
            guard curvatureBuffer[0].angleWidth.isNaN else {
                return
            }
            
            // NOTE: We're not holding a lock over the distances buffer. This would only become a problem if our framerate increases dramatically but still
            let distancesPointer = laserDistancesBuffer.contents().assumingMemoryBound(to: Float.self)
            let distancesBuffer = UnsafeBufferPointer(start: distancesPointer, count: Laser.sampleCount)
            
            var indices: [Int] = []
            
            let upperAngleThreshold: Float = .pi / 3.0
            let lowerAngleThreshold: Float = 0.05
            
            let discontinuityThreshold: Float = 0.25
            
            enum ScanState {
                case invalid
                case low
                case high(Int, LaserPoint)
            }
            
            var state = ScanState.invalid
            
            for pair in curvatureBuffer.enumerated() {
                
                // Add corners
                
                if pair.element.prevDiscontinuity || pair.element.nextDiscontinuity {
                    
                    state = .invalid
                    
                } else {
                    
                    switch state {
                    case .invalid:
                        
                        if pair.element.angleWidth < lowerAngleThreshold {
                            state = .low
                        }
                        
                    case .low:
                        
                        if pair.element.angleWidth > upperAngleThreshold {
                            state = .high(pair.offset, pair.element)
                        }
                        
                    case let .high(index, point):
                        
                        if pair.element.angleWidth < lowerAngleThreshold {
                            
                            state = .low
                            indices.append(index)
                            
                        } else if pair.element.angleWidth > point.angleWidth {
                            
                            state = .high(pair.offset, pair.element)
                        }
                    }
                }
                
                // Add occluding points
                if (20..<(distancesBuffer.count - 20)).contains(pair.offset) {
                    
                    let nextDistance = distancesBuffer[pair.offset + 1] - distancesBuffer[pair.offset]
                    
                    // pair.element.nextAngle < -.pi / 12.0
                    if abs(pair.element.averagePrevAngle) < 0.1 && nextDistance > discontinuityThreshold && !pair.element.prevDiscontinuity {
                        indices.append(pair.offset)
                    }
                    
                    let prevDistance = distancesBuffer[pair.offset - 1] - distancesBuffer[pair.offset]
                    
                    // pair.element.prevAngle > .pi / 12.0
                    if abs(pair.element.averageNextAngle) < 0.1 && prevDistance > discontinuityThreshold && !pair.element.nextDiscontinuity {
                        indices.append(pair.offset)
                    }
                }
            }
            
            // Copy indicies to local buffer for rendering
            
            self.cornersBufferCount = indices.count
            indices.map { UInt16($0) }.withUnsafeBytes { body in
                self.cornersBuffer.contents().copyBytes(from: body.baseAddress!, count: body.count)
            }
            
            // Project distances to points for identified indicies
            
            let positions: [MapPoint] = indices.map { index in
                
                let distance = distancesBuffer[index]
                let laserPoint = curvatureBuffer[index]
                
                return MapPoint(id: UUID(), position: float4(distance * cos(Laser.angle(for: index)), distance * sin(Laser.angle(for: index)), 0.0, 1.0), startAngle: laserPoint.startAngle, endAngle: laserPoint.endAngle)
            }
            
            completionHandler(positions)
        }
    }
    
    func renderCorners(commandEncoder: MTLRenderCommandEncoder, commandBuffer: MTLCommandBuffer, projectionMatrix: float4x4, laserDistancesBuffer: MTLBuffer) {
        
        guard cornersBufferCount > 0 else { return }
        
        self.semaphore.wait()
        
        commandEncoder.setRenderPipelineState(cornersPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        var uniforms = CornerUniforms(projectionMatrix: projectionMatrix.cmatrix, angleStart: Laser.angleStart, angleIncrement: Laser.angleIncrement, pointSize: 12.0)
        
        commandEncoder.setVertexBuffer(laserDistancesBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        var color = float4(1.0, 0.0, 0.0, 1.0)
        
        commandEncoder.setFragmentBytes(&color, length: MemoryLayout.stride(ofValue: color), at: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .point, indexCount: cornersBufferCount, indexType: .uint16, indexBuffer: cornersBuffer, indexBufferOffset: 0)
        
        commandBuffer.addCompletedHandler { _ in
            self.semaphore.signal()
        }
    }
}
