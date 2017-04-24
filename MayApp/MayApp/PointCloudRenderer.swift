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

public final class PointCloudRenderer {
    
    static let points = 480 * 640
    
    // Kinect camera instrinsic data from PCL
    // need to get calibrated to get more accurate data
    // Initial constants from Nicolas Burrus
    // http://nicolas.burrus.name/index.php/Research/KinectCalibration#tocLink5
    let fx: Float = 1.0 / 5.9421434211923247e+02
    let fy: Float = 1.0 / 5.9104053696870778e+02
    let cx: Float = 3.3930780975300314e+02
    let cy: Float = 2.4273913761751615e+02
    
    public let pointcloudBuffer: MTLBuffer
    
    public var cameraRotation = float3(0, Float.pi, 0)
    let cameraOffset: Float = 5
    
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
    
    let commandQueue: MTLCommandQueue
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue) {
        
        pointcloudBuffer = library.device.makeBuffer(length: PointCloudRenderer.points * MemoryLayout<Camera.Depth>.stride, options: [])
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "pointCloudVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "pointCloudFragment")
        
        pointcloudRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        self.commandQueue = commandQueue
    }
    
    public func updatePointcloud(with depthbuffer: [Camera.Depth]){
        depthbuffer.withUnsafeBytes { body in
            pointcloudBuffer.contents().copyBytes(from: body.baseAddress!, count: body.count)
        }
    }
    
    func renderPointcloud(with commandEncoder: MTLRenderCommandEncoder, aspectRatio: Float, camera: Camera) {
        
        // Calculate projection matrix
        
        let rotationX = float4x4(rotationAbout: float3(1.0, 0.0, 0.0), by: cameraRotation.x)
        let rotationY = float4x4(rotationAbout: float3(0.0, 1.0, 0.0), by: cameraRotation.y)
        let rotationZ = float4x4(rotationAbout: float3(0.0, 0.0, 1.0), by: cameraRotation.z)
        
        let cameraTranslation = float3(0.0, 0.0, -cameraOffset)
        let viewMatrix = float4x4(translation: cameraTranslation) * rotationX * rotationY * rotationZ * float4x4(translation: cameraTranslation)
        
        let projectionMatrix = float4x4(perspectiveWithAspectRatio: aspectRatio, fieldOfViewY: 0.4 * .pi, near: 0.1, far: 100.0)
        
        // Make uniforms
        
        var pointcloudUpdateUniforms = PointCloudUpdateUniforms(
            width: 640,
            height: 480,
            fx: fx,
            fy: fy,
            cx: cx,
            cy: cy,
            projectionMatrix: projectionMatrix * viewMatrix)
        
        // Draw
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        commandEncoder.setDepthStencilState(pointcloudRenderPipeline.device.makeDepthStencilState(descriptor: depthStencilDescriptor))
        
        commandEncoder.setRenderPipelineState(pointcloudRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(pointcloudBuffer, offset: 0, at: 0);
        commandEncoder.setVertexBytes(&pointcloudUpdateUniforms, length: MemoryLayout.stride(ofValue: pointcloudUpdateUniforms), at: 1)
        commandEncoder.setVertexTexture(camera.texture, at: 0)
        commandEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: PointCloudRenderer.points)
    }
}
