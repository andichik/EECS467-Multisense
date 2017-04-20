//
//  PathRenderer.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/04/04.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd
import MetalKit

#if os(iOS)
    import MetalPerformanceShaders
#endif

public final class PathRenderer {
    
    let pathMapRenderer: PathMapRenderer
    
    static let pfmapDiv = 4 // Size of PFMap will be 1/pfMapDiv of Original Map
    static let pfmapDim: Int! = Map.texels / pfmapDiv // Dimension
    static let pfmapSize: Int! = pfmapDim * pfmapDim
    
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    
    let scaleDownMapPipeline: MTLComputePipelineState
    var pfmapTexture: MTLTexture
    var pfmapBuffer: MTLBuffer

    let pathRenderPipeline: MTLRenderPipelineState
    let mapRenderPipeline: MTLRenderPipelineState
    
    var scaleDownMapUniforms: ScaleDownMapUniforms
    
    let pathBuffer: TypedMetalBuffer<float4>
    
    static let pixelFormat = MTLPixelFormat.r32Float
    
    let squareMesh: SquareMesh
    
    let threadsPerThreadGroup: MTLSize
    let threadgroupsPerGrid: MTLSize
    
    struct ScaleDownMapUniforms {
        var pfmapDiv: UInt32
        var pfmapDim: UInt32
    }
    
    struct PathUniforms {
        var projectionMatrix: float4x4
//        var path: [uint2]
        var pathSize: Int
        var pfmapDim: Int
    }
    
    static let textureDescriptor: MTLTextureDescriptor = {
        
        // Texture values will be in [-1.0, 1.0] where -1.0 is free and 1.0 is occupied
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: pfmapDim, height: pfmapDim, mipmapped: false)
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        return textureDescriptor
    }()
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue) {
        
        // Path Map (Laser Scan Map)
        self.pathMapRenderer = PathMapRenderer(library: library, pixelFormat: pixelFormat, commandQueue: commandQueue)
        
        // Path map texture
        self.pfmapBuffer = library.device.makeBuffer(length: PathRenderer.pfmapSize * MemoryLayout<Float>.stride, options: [])
        #if os(iOS)
            self.pfmapTexture = pfmapBuffer.makeTexture(descriptor: PathRenderer.textureDescriptor, offset: 0, bytesPerRow: PathRenderer.pfmapDim * MemoryLayout<Float>.stride)
        #else
            self.pfmapTexture = library.device.makeTexture(descriptor: PathRenderer.textureDescriptor)
        #endif
        
        // Create path buffer
        pathBuffer = TypedMetalBuffer(device: library.device)
        
        // Setup Pipeline
        let scaleDownMapFunction = library.makeFunction(name: "scaleDownMap")!
        scaleDownMapPipeline = try! library.device.makeComputePipelineState(function: scaleDownMapFunction)
        
        // Thread Execution Sizes
        let threadgroupWidth = scaleDownMapPipeline.threadExecutionWidth
        let threadgroupHeight = scaleDownMapPipeline.maxTotalThreadsPerThreadgroup / threadgroupWidth
        threadsPerThreadGroup = MTLSize(width: threadgroupWidth, height: threadgroupHeight, depth: 1)
//        threadgroupsPerGrid = MTLSize(width: (Map.texels + threadgroupWidth - 1) / threadgroupWidth, height: (Map.texels + threadgroupHeight - 1) / threadgroupHeight, depth: 1)
        
        // Thread Execution Sizes (for scale Down)
        threadgroupsPerGrid = MTLSize(width: (PathRenderer.pfmapDim + threadgroupWidth - 1) / threadgroupWidth, height: (PathRenderer.pfmapDim + threadgroupHeight - 1) / threadgroupHeight, depth: 1)
        
        // Initialize Uniform
        scaleDownMapUniforms = ScaleDownMapUniforms(pfmapDiv: UInt32(PathRenderer.pfmapDiv), pfmapDim: UInt32(PathRenderer.pfmapDim))
        
        // Square Mesh
        squareMesh = SquareMesh(device: library.device)
        
        // Make Uniforms
        // TODO
        
        // Map Render Pipeline
        let mapRenderDescriptor = MTLRenderPipelineDescriptor()
        mapRenderDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        mapRenderDescriptor.depthAttachmentPixelFormat = .depth32Float
        mapRenderDescriptor.vertexFunction = library.makeFunction(name: "pfmapVertex")
        mapRenderDescriptor.fragmentFunction = library.makeFunction(name: "pfmapFragment")
        
        mapRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: mapRenderDescriptor)
        
        // Path Render Pipeline
        let pathRenderDescriptor = MTLRenderPipelineDescriptor()
        pathRenderDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        pathRenderDescriptor.depthAttachmentPixelFormat = .depth32Float
        pathRenderDescriptor.vertexFunction = library.makeFunction(name: "plainVertex")
        pathRenderDescriptor.fragmentFunction = library.makeFunction(name: "plainFragment")
        
        pathRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: pathRenderDescriptor)
        
        // Store Command Queue
        self.commandQueue = commandQueue
        self.library = library
        
    }
    
    func scaleDownMap(commandBuffer: MTLCommandBuffer, map: Map) {
        //        let pfBlitEncoder = pfcommandBuffer.makeBlitCommandEncoder()
        //        pfBlitEncoder.fill(buffer: pfmapBuffer, range: NSMakeRange(0, 32), value: 0)
        
        // Create Command Encoder
        let scaleDownMapCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        scaleDownMapCommandEncoder.label = "Scale Down Map"
        scaleDownMapCommandEncoder.setComputePipelineState(scaleDownMapPipeline)
        scaleDownMapCommandEncoder.setTexture(map.texture, at: 0)
        scaleDownMapCommandEncoder.setTexture(pfmapTexture, at: 1)
        scaleDownMapCommandEncoder.setBuffer(pfmapBuffer, offset: 0, at: 0)
        scaleDownMapCommandEncoder.setBytes(&scaleDownMapUniforms, length: MemoryLayout.stride(ofValue: scaleDownMapUniforms), at: 1)
        
        
        
        scaleDownMapCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        scaleDownMapCommandEncoder.endEncoding()
        
//        commandBuffer.commit()
//        commandBuffer.waitUntilCompleted()
    }
    
    func makePath(bestPose: Pose, algorithm: String, destination: float2) {
        
        switch algorithm {
        case "A*":
            NSLog("Using A*")
            
            let astarDestination = float2(destination.x / Map.meters + 0.5,
                                          0.5 - destination.y / Map.meters)
            
            let astar = AStar(map: pfmapBuffer, dimension: PathRenderer.pfmapDim, destination: astarDestination)
            
            let position = float2(bestPose.position.x / Map.meters + 0.5,
                                  0.5 - bestPose.position.y / Map.meters)
            
            let start = uint2(UInt32(position.x * Float(PathRenderer.pfmapDim)), UInt32(position.y * Float(PathRenderer.pfmapDim)))
            _ = astar.run(start: start, thres: 0, pathBuffer: pathBuffer)
            
        default: NSLog("Default Algorithm")
        }
    }
    
    public func drawMap(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
//        self.pfmapTexture = pfmapBuffer.makeTexture(descriptor: PathRenderer.textureDescriptor, offset: 0, bytesPerRow: PathRenderer.pfmapDim * MemoryLayout<Float>.stride)
        
        var uniforms = PathUniforms(projectionMatrix: projectionMatrix, pathSize: 0, pfmapDim: PathRenderer.pfmapDim)
        
        
        commandEncoder.setRenderPipelineState(mapRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(squareMesh.vertexBuffer, offset: 0, at:0)
        commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        commandEncoder.setFragmentTexture(pfmapTexture, at:0)
        commandEncoder.setFragmentBytes(&uniforms, length: MemoryLayout.stride(ofValue: uniforms), at: 0)
        
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: squareMesh.vertexCount)
    }
    
    public func drawPath(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4) {
        
        guard !pathBuffer.isEmpty else { return }
        
        var matrix = projectionMatrix

        commandEncoder.setRenderPipelineState(pathRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(pathBuffer.metalBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&matrix, length: MemoryLayout.stride(ofValue: matrix), at: 1)
        
        var color = float4(0.0, 1.0, 0.5, 1.0)
        
        commandEncoder.setFragmentBytes(&color, length: MemoryLayout.stride(ofValue: color), at: 0)
        
        commandEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: pathBuffer.count)
    }
    
}
