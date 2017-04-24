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

public final class PathRenderer {
    
    let pathMapRenderer: PathMapRenderer
    
    static let pfmapDiv = 8 // Size of PFMap will be 1/pfMapDiv of Original Map
    static let pfmapDim: Int! = PathMapRenderer.texels / pfmapDiv // Dimension
    static let pfmapSize: Int! = pfmapDim * pfmapDim
    
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    
    let scaleDownMapPipeline: MTLComputePipelineState
    var pfmapTexture: MTLTexture
    var pfmapBuffer: MTLBuffer

    let pathRenderPipeline: MTLRenderPipelineState
    let mapRenderPipeline: MTLRenderPipelineState
    
    var scaleDownMapUniforms: ScaleDownMapUniforms
    
    public let pathBuffer: TypedMetalBuffer<float4>
    
    static let pixelFormat = MTLPixelFormat.r32Float
    
    let squareMesh: SquareMesh
    
    let threadsPerThreadGroup: MTLSize
    let threadgroupsPerGrid: MTLSize
    
//    let astar: AStar
    let astar = AStar(dimension: pfmapDim)
    static let maxDuration = TimeInterval(exactly: 0.1)
    
    let backgroundQueue = DispatchQueue(label: "Path finding queue", qos: .utility)
    
    struct ScaleDownMapUniforms {
        var pfmapDiv: UInt32
        var pfmapDim: UInt32
        var pfmapRange: UInt32
        var pose: uint2
    }
    
    struct PathUniforms {
        var projectionMatrix: float4x4
        var pathSize: Int
        var pfmapDim: Int
    }
    
    static let textureDescriptor: MTLTextureDescriptor = {
        
        // Texture values will be in [-1.0, 1.0] where -1.0 is free and 1.0 is occupied
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: pfmapDim, height: pfmapDim, mipmapped: false)
        
        #if os(iOS)
            textureDescriptor.storageMode = .shared
        #elseif os(macOS)
            textureDescriptor.storageMode = .managed
        #endif
        
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
        
        // Thread Execution Sizes (for scale Down)
        threadgroupsPerGrid = MTLSize(width: (PathRenderer.pfmapDim + threadgroupWidth - 1) / threadgroupWidth, height: (PathRenderer.pfmapDim + threadgroupHeight - 1) / threadgroupHeight, depth: 1)
        
        // Initialize Uniform
        let vehicleRangeTexels = UInt32(PathMapRenderer.vehicleRange * PathMapRenderer.texelsPerMeter)
        // Normalized pose to [0,1] wrt snapshot
        let poseX = PathMapRenderer.pose.position.x / PathMapRenderer.meters + 0.5
        let poseY = 0.5 - PathMapRenderer.pose.position.y / PathMapRenderer.meters
        // Convert to coordinates in down-size search grid
        let pose = uint2(UInt32(poseX * Float(PathRenderer.pfmapDim)), UInt32(poseY * Float(PathRenderer.pfmapDim)))
        
        scaleDownMapUniforms = ScaleDownMapUniforms(pfmapDiv: UInt32(PathRenderer.pfmapDiv),
                                                    pfmapDim: UInt32(PathRenderer.pfmapDim),
                                                    pfmapRange: vehicleRangeTexels,
                                                    pose: pose)
        
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
        
        // Initialize A* Object
//        self.astar = AStar(dimension: PathRenderer.pfmapDim)
        
    }
    
    func scaleDownMap(commandBuffer: MTLCommandBuffer, texture: MTLTexture) {
        //        let pfBlitEncoder = pfcommandBuffer.makeBlitCommandEncoder()
        //        pfBlitEncoder.fill(buffer: pfmapBuffer, range: NSMakeRange(0, 32), value: 0)
        
        // Create Command Encoder
        let scaleDownMapCommandEncoder = commandBuffer.makeComputeCommandEncoder()
        scaleDownMapCommandEncoder.label = "Scale Down Map"
        scaleDownMapCommandEncoder.setComputePipelineState(scaleDownMapPipeline)
        scaleDownMapCommandEncoder.setTexture(texture, at: 0)
        scaleDownMapCommandEncoder.setTexture(pfmapTexture, at: 1)
        scaleDownMapCommandEncoder.setBuffer(pfmapBuffer, offset: 0, at: 0)
        scaleDownMapCommandEncoder.setBytes(&scaleDownMapUniforms, length: MemoryLayout.stride(ofValue: scaleDownMapUniforms), at: 1)
        
        
        
        scaleDownMapCommandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        scaleDownMapCommandEncoder.endEncoding()
        
//        commandBuffer.commit()
//        commandBuffer.waitUntilCompleted()
    }
    
    func makePath(bestPose: Pose, algorithm: String, destination: float2, completionHandler: @escaping (_ endTime: Date, _ pathBuffer: TypedMetalBuffer<float4>) -> Void) {
        
        backgroundQueue.async {
            
            // Do all the work
            
            // Find new destination that is within the scope of referenced map.
            // New destination has same direction as user-defined destination
            let distanceX: Float = destination.x - bestPose.position.x
            let distanceY: Float = destination.y - bestPose.position.y
            
            let ratioX: Float = max(abs(distanceX / (PathMapRenderer.meters / 2)), 1)
            let ratioY: Float = max(abs(distanceY / (PathMapRenderer.meters / 2)), 1)
            
            let localX = (ratioX > ratioY) ? distanceX / ratioX : distanceX / ratioY
            let localY = (ratioX > ratioY) ? distanceY / ratioX : distanceY / ratioY
            
            let localDestination = float2(localX,localY)
            
            // Choose Pathplanning algorithm
            switch algorithm {
            case "A*":
                print("Using A*")
                print("Distance from pose: ", localDestination.x, localDestination.y)
                
                // Preparation:
                // Normalized meters to [0,1] position in search grid.
                let normalizedDestination = float2(localDestination.x / PathMapRenderer.meters + 0.5,
                                                   0.5 - localDestination.y / PathMapRenderer.meters)
                
                // Convert to coordinates in search grid
                let astarDestination: uint2 = uint2(UInt32(normalizedDestination.x * Float(PathRenderer.pfmapDim)), UInt32(normalizedDestination.y * Float(PathRenderer.pfmapDim)))
                
                /***** A* BEGIN ******/
                self.astar.loadMap(buffer: self.pfmapBuffer)
                self.astar.loadDestination(destination: astarDestination)
                
                // This will dictate where A* path starts
                let localStart = PathMapRenderer.pose
                
                // Normalize meters to [0,1] position in search grid.
                let normalizedStart = float2(localStart.position.x / PathMapRenderer.meters + 0.5,
                                             0.5 - localStart.position.y / PathMapRenderer.meters)
                
                // Convert to coordinates in search grid
                let astarStart = uint2(UInt32(normalizedStart.x * Float(PathRenderer.pfmapDim)), UInt32(normalizedStart.y * Float(PathRenderer.pfmapDim)))
                
                _ = self.astar.run(start: astarStart, thres: 0, pathBuffer: self.pathBuffer)
                
                /***** A* END ******/
                
                
//                let end_time = Date() // End timer
                
//                print("A* took: ", end_time.timeIntervalSince(start_time))
                
            default: print("Default Algorithm")
            }
            print("Completed A*")
            
            DispatchQueue.main.async {

                // call completion handler
                completionHandler(Date(), self.pathBuffer)
                
            }
        }
        
        
    }
    
    let simplifyFactor = 2
    
    func simplifyPath() -> TypedMetalBuffer<float4> {
        
        let simplifiedPathBuffer: TypedMetalBuffer<float4> = TypedMetalBuffer(device: library.device)
        
        guard !pathBuffer.isEmpty else { return simplifiedPathBuffer }
        
//        var lastAngle: Float? = nil
//        var lastNode: float4? = nil
        var count: Int = 2
        var prevPoint = float2()
        for point in pathBuffer {
//            if((count % 2 == 1)) {
//
//                let angle: Float = atanf((lastNode!.x - point.x) / (lastNode!.y - point.y))
//
//                if((lastAngle == nil) || (angle != lastAngle)) {
//                    simplifiedPathBuffer.append(point)
//                    lastAngle = angle
//                }
//            } else if (count == simplifyFactor) {
//                simplifiedPathBuffer.append(point)
//                lastNode = point
//                count = 0
//            }
//            if(count == simplifyFactor) {
//                simplifiedPathBuffer.append(point)
//                lastNode = point
//                count = 0
//            }
//            count += 1
            let dist = sqrt(pow(point.x - prevPoint.x,2) + pow(point.y - prevPoint.y,2))
            if dist > 0.5 {
                simplifiedPathBuffer.append(point)
                prevPoint.x = point.x
                prevPoint.y = point.y
            }
//            count += 1
//            if (count == 8) {
//                simplifiedPathBuffer.append(point)
//                count = 0
//            }
        }
        
        return simplifiedPathBuffer
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
    
    public func drawPath(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4, path: TypedMetalBuffer<float4>) {
        
        guard !path.isEmpty else { return }
        
        var matrix = projectionMatrix

        commandEncoder.setRenderPipelineState(pathRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(path.metalBuffer, offset: 0, at: 0)
        commandEncoder.setVertexBytes(&matrix, length: MemoryLayout.stride(ofValue: matrix), at: 1)
        
        var color = float4(0.0, 1.0, 0.5, 1.0)
        
        commandEncoder.setFragmentBytes(&color, length: MemoryLayout.stride(ofValue: color), at: 0)
        
        commandEncoder.drawPrimitives(type: .lineStrip, vertexStart: 0, vertexCount: path.count)
    }
    
}
