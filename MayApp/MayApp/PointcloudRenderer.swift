//
//  PointcloudRenderer.swift
//  MayApp
//
//  Created by Yanqi Liu on 3/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

public final class PointcloudRenderer {
    static let points = 480*640;
    
    //Kinect camera instrinsic data from PCL
    //need to get calibrated to get more accurate data
    let fx: Float = 1.0 / 5.9421434211923247e+02;
    let fy: Float = 1.0 / 5.9104053696870778e+02;
    //let fx: Float = 1.0;
    //let fy: Float = 1.0;
    let cx: Float =  3.3930780975300314e+02;
    let cy: Float = 2.4273913761751615e+02;
    
    var pointcloudBuffer: MTLBuffer
    
    let mmtoM: Float = 0.001;
    
    //let pointcloudUpdatePipeline: MTLComputePipelineState
    
    struct PointCloudUpdateUniforms {
        var width: Float
        var height: Float
        var fx: Float
        var fy: Float
        var cx: Float
        var cy: Float
        var projectionMatrix: float4x4
    }
    
    let pointcloudRenderPipeline: MTLRenderPipelineState
    
    let pointcloudRenderScalematrix = float4x4(diagonal: float4(0.02, 0.02, 0.02, 1.0))
    

    
    let commandQueue: MTLCommandQueue
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue) {
        
        pointcloudBuffer = library.device.makeBuffer(length: PointcloudRenderer.points*MemoryLayout<UInt32>.stride, options: [])
        
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "pointcloudVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "pointcloudFragment")
        
        pointcloudRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        self.commandQueue = commandQueue
        
    }
    
    public func updatePointcloud(with depthbuffer: [UInt16]){
        depthbuffer.withUnsafeBytes { body in
            pointcloudBuffer.contents().copyBytes(from: body.baseAddress!, count: body.count)
        }
    }
    
    func renderPointcloud(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4, camera: Camera) {
        
        var pointcloudUpdateUniforms = PointCloudUpdateUniforms(
            width: 640,
            height: 480,
            fx: fx,
            fy: fy,
            cx: cx,
            cy: cy,
            projectionMatrix: projectionMatrix)
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        commandEncoder.setDepthStencilState(pointcloudRenderPipeline.device.makeDepthStencilState(descriptor: depthStencilDescriptor))
        
        commandEncoder.setRenderPipelineState(pointcloudRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        //commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(pointcloudBuffer, offset: 0, at: 0);
        commandEncoder.setVertexBytes(&pointcloudUpdateUniforms, length: MemoryLayout.stride(ofValue: pointcloudUpdateUniforms), at: 1)
        commandEncoder.setVertexTexture(camera.texture, at: 0)
        commandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: PointcloudRenderer.points)
    }
    
    
}
