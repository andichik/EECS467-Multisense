//
//  PFMap.swift
//  MayApp
//
//  Created by Doan Ichikawa on 2017/03/23.
//  Copyright © 2017年 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

#if os(iOS)
    import MetalPerformanceShaders
#endif

/*precedencegroup PowerPrecedence { higherThan: MultiplicationPrecedence }
infix operator ^^ : PowerPrecedence
func ^^ (radix: Int, power: Int) -> Int {
    return Int(pow(Double(radix), Double(power)))
}*/


public final class PFMap {
    
    static let pfmapDiv = 32 // Size of PFMap will be 1/pfMapDiv of Original Map
    static let pfmapDim: Int! = Map.texels / pfmapDiv // Dimension
    static let pfmapSize: Int! = pfmapDim * pfmapDim
    
    let commandQueue: MTLCommandQueue
    let library: MTLLibrary
    
    typealias MapResizeHandler = (_ map: Map, _ newMap: Map) -> Void
    
    let scaleDownMapPipeline: MTLComputePipelineState
    var pfmapTexture: MTLTexture
    var pfmapBuffer: MTLBuffer
    
    let threadsPerThreadGroup: MTLSize
    let threadgroupsPerGrid: MTLSize
    
    let pfthreadgroupsPerGrid: MTLSize
    
    struct ScaleDownMapUniforms {
        var pfmapDiv: UInt32
        var pfmapDim: UInt32
    }
    
    var scaleDownMapUniforms: ScaleDownMapUniforms
    
    static let pixelFormat = MTLPixelFormat.r16Snorm
    
    static let textureDescriptor: MTLTextureDescriptor = {
        
        // Texture values will be in [-1.0, 1.0] where -1.0 is free and 1.0 is occupied
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: pfmapDim, height: pfmapDim, mipmapped: false)
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.shaderRead, .renderTarget]
        return textureDescriptor
    }()
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue) {
        
        // Initialize resized map
        self.pfmapBuffer = library.device.makeBuffer(length: PFMap.pfmapSize * MemoryLayout<Float>.stride, options: [])
        #if os(iOS)
        self.pfmapTexture = self.pfmapBuffer.makeTexture(descriptor: PFMap.textureDescriptor, offset: 0, bytesPerRow: PFMap.pfmapDim * MemoryLayout<Float>.stride)
            #else
            self.pfmapTexture = library.device.makeTexture(descriptor: PFMap.textureDescriptor)
            #endif
        
        // Store commandQueue and library
        self.commandQueue = commandQueue
        self.library = library
        
        // Setup Pipeline
        let scaleDownMapFunction = library.makeFunction(name: "scaleDownMap")!
        scaleDownMapPipeline = try! library.device.makeComputePipelineState(function: scaleDownMapFunction)
        
        // Thread Execution Sizes
        let threadgroupWidth = scaleDownMapPipeline.threadExecutionWidth
        let threadgroupHeight = scaleDownMapPipeline.maxTotalThreadsPerThreadgroup / threadgroupWidth
        threadsPerThreadGroup = MTLSize(width: threadgroupWidth, height: threadgroupHeight, depth: 1)
        threadgroupsPerGrid = MTLSize(width: (Map.texels + threadgroupWidth - 1) / threadgroupWidth, height: (Map.texels + threadgroupHeight - 1) / threadgroupHeight, depth: 1)
        
        // Thread Execution Sizes (for scale Down)
        pfthreadgroupsPerGrid = MTLSize(width: (PFMap.pfmapDim + threadgroupWidth - 1) / threadgroupWidth, height: (PFMap.pfmapDim + threadgroupHeight - 1) / threadgroupHeight, depth: 1)
        
        // Initialize Uniform
        scaleDownMapUniforms = ScaleDownMapUniforms(pfmapDiv: UInt32(PFMap.pfmapDiv), pfmapDim: UInt32(PFMap.pfmapDim))
        
    }
    func scaleDownMap(_ map: Map) {
        // Create Command Buffer
        let pfcommandBuffer = commandQueue.makeCommandBuffer()
        
        let pfBlitEncoder = pfcommandBuffer.makeBlitCommandEncoder()
        pfBlitEncoder.fill(buffer: pfmapBuffer, range: NSMakeRange(0, 32), value: 0)
        
        // Populate Uniform (constants used by metal kernel function)
            
            
        // Create Command Encoder
        let scaleDownMapCommandEncoder = pfcommandBuffer.makeComputeCommandEncoder()
        scaleDownMapCommandEncoder.label = "Scale Down Map"
        scaleDownMapCommandEncoder.setComputePipelineState(scaleDownMapPipeline)
        scaleDownMapCommandEncoder.setTexture(map.texture, at: 0)
        scaleDownMapCommandEncoder.setTexture(pfmapTexture, at: 1)
        scaleDownMapCommandEncoder.setBuffer(pfmapBuffer, offset: 0, at: 0)
        scaleDownMapCommandEncoder.setBytes(&scaleDownMapUniforms, length: MemoryLayout.stride(ofValue: scaleDownMapUniforms), at: 1)
            
        scaleDownMapCommandEncoder.dispatchThreadgroups(pfthreadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadGroup)
        scaleDownMapCommandEncoder.endEncoding()
        
        pfcommandBuffer.commit()
//        pfcommandBuffer.waitUntilCompleted()
    }
    //func makeMipmap() {}
    func LanczosScale(map: Map, commandBuffer: MTLCommandBuffer) {
        
        #if os(iOS)
            // Initialize texture
            let pfMap = MPSImageLanczosScale(device: library.device)
            
            // Add Scale Property
            let pfScale = Double(PFMap.pfmapSize / Map.texels)
            var transform = MPSScaleTransform(scaleX: pfScale, scaleY: pfScale, translateX: 0, translateY: 0)
            
            // Invoke Transform
            withUnsafePointer(to: &transform) { (transformPtr: UnsafePointer<MPSScaleTransform>) -> () in
                pfMap.scaleTransform = transformPtr
                pfMap.encode(commandBuffer: commandBuffer, sourceTexture: map.texture, destinationTexture: pfmapTexture)
            }
        #else
            return
        #endif
    }
}
