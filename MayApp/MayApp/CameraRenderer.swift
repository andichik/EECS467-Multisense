//
//  CameraRenderer.swift
//  MayApp
//
//  Created by Yanqi Liu on 3/23/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd
import CoreImage

public final class CameraRenderer {
    
    let camera: Camera
    
    struct CameraUpdateVertexUniforms {
        var projectionMatrix: float4x4
    }
    
    public var doorsignCollection = [String: float4]()
    
    let fx: Float = 1.0 / 5.9421434211923247e+02
    let fy: Float = 1.0 / 5.9104053696870778e+02
    let cx: Float = 3.3930780975300314e+02
    let cy: Float = 2.4273913761751615e+02

    var cameraUpdateVertexUniforms: CameraUpdateVertexUniforms
    
    let squareMesh: SquareMesh
    
    let cameraRenderPipeline: MTLRenderPipelineState
    
    let commandQueue: MTLCommandQueue
    
    let library: MTLLibrary
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue, quality: Camera.Quality) {
        
        // Make camera
        camera = Camera(device: library.device, quality: quality)
        
        // Make uniforms
        cameraUpdateVertexUniforms = CameraUpdateVertexUniforms(projectionMatrix: float4x4())
        
        // Make square mesh
        squareMesh = SquareMesh(device: library.device)
        
        // Make camera render pipeline
        
        let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        renderPipelineDescriptor.vertexFunction = library.makeFunction(name: "cameraVertex")
        renderPipelineDescriptor.fragmentFunction = library.makeFunction(name: "cameraFragmentFloat")
        
        cameraRenderPipeline = try! library.device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
        
        self.library = library
        self.commandQueue = commandQueue
    }
    
    public func updateCameraTexture(with colorbuffer: [Camera.Color]) {
        
        let floatbuffer: [float4] = colorbuffer.map {
            return float4(Float($0.r) / 255.0, Float($0.g) / 255.0, Float($0.b) / 255.0, 1.0)
        }
        
        floatbuffer.withUnsafeBytes { body in
            camera.texture.replace(region: MTLRegionMake2D(0, 0, camera.quality.width, camera.quality.height),
                mipmapLevel:0, withBytes: body.baseAddress!, bytesPerRow: camera.quality.width * MemoryLayout<float4>.stride)
        }
    }
    
    public func tagDetectionAndPoseEsimtation(with depthbuffer: [Camera.Depth], from pose: Pose) -> [String] {
        
        var messageCollection = [String]()
        let cameraFrame = CIImage(mtlTexture: camera.texture)!
        let context = CIContext(mtlDevice: self.library.device);
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: context)!
        
        let features = detector.features(in: cameraFrame)
        
        var boundLocation=[Int](repeating: 0, count:4)
        
        for feature in features {
            
            guard let feature = feature as? CIQRCodeFeature , let message = feature.messageString else {
                continue
            }
            
            if(doorsignCollection[message] == nil){
                
                print("bottom left: \(feature.bottomLeft), bottom right: \(feature.bottomRight), top left: \(feature.topLeft), top right: \(feature.topRight)");
                boundLocation[0] = ((Int(feature.bottomLeft.y)) * camera.quality.width + (Int(feature.bottomLeft.x)))
                boundLocation[1] = ((Int(feature.bottomRight.y)) * camera.quality.width + (Int(feature.bottomRight.x)))
                boundLocation[2] = ((Int(feature.topLeft.y)) * camera.quality.width + (Int(feature.topLeft.x)))
                boundLocation[3] = ((Int(feature.topRight.y)) * camera.quality.width + (Int(feature.topRight.x)))
                
                let centerY = (Int(feature.bottomLeft.y) + Int(feature.topRight.y))/2
                let centerX = (Int(feature.bottomLeft.x) + Int(feature.topRight.x))/2
                let centerLocation = centerY * camera.quality.width + centerX
                
                let depth = Float(depthbuffer[centerLocation]) * 0.001
                
                if(depth != 0){
                    print("depth at corner: \(depth)");
                    let x = (Float(feature.bottomLeft.x) - self.cx) * depth * self.fx
                    //let y = (Float(-feature.bottomLeft.y) + self.cy) * depth * self.fy
                    let z = depth
                        
                    let location = pose.matrix * float4(z, x, 0.0, 1.0)
                    print("add new string \(message) with location: \(location.x) \(location.y) \(location.z)")
                    messageCollection.append(message)
                    doorsignCollection[message] = location
                }
            }
        }
        
        return messageCollection
    }
    
    struct RenderUniforms {
        
        var projectionMatrix: float4x4
    }
    
    func renderCamera(with commandEncoder: MTLRenderCommandEncoder, projectionMatrix: float4x4){
        
        var uniforms = RenderUniforms(projectionMatrix: projectionMatrix)
        
        commandEncoder.setRenderPipelineState(cameraRenderPipeline)
        commandEncoder.setFrontFacing(.counterClockwise)
        commandEncoder.setCullMode(.back)
        
        commandEncoder.setVertexBuffer(squareMesh.vertexBuffer, offset:0, at:0)
        commandEncoder.setVertexBytes(&uniforms, length:MemoryLayout.stride(ofValue: uniforms), at: 1)
        
        commandEncoder.setFragmentTexture(camera.texture, at: 0)
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: squareMesh.vertexCount)
    }
}
