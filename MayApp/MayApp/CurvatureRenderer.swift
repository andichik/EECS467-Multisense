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
        
        curvatureBuffer = library.device.makeBuffer(length: Laser.sampleCount * MemoryLayout<Float>.stride, options: [])
        
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
    
    func calculateCurvature(commandBuffer: MTLCommandBuffer, laserDistancesBuffer: MTLBuffer) {
        
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
            
            // Find corner indices
            
            let pointer = self.curvatureBuffer.contents().assumingMemoryBound(to: Float.self)
            let buffer = UnsafeBufferPointer(start: pointer, count: Laser.sampleCount)
            
            var indices: [UInt16] = []
            
            let angleThreshold: Float = .pi / 3.0
            var localMax: (Int, Float)? = nil
            
            for pair in buffer.enumerated() {
                
                if let (maxIndex, maxAngle) = localMax {
                    
                    if pair.element > maxAngle {
                        localMax = pair
                    } else if pair.element < angleThreshold {
                        indices.append(UInt16(maxIndex))
                        localMax = nil
                    }
                    
                } else {
                    
                    if pair.element > angleThreshold {
                        localMax = pair
                    }
                }
            }
            
            self.cornersBufferCount = indices.count
            indices.withUnsafeBytes { body in
                self.cornersBuffer.contents().copyBytes(from: body.baseAddress!, count: body.count)
            }
            
            self.semaphore.signal()
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
