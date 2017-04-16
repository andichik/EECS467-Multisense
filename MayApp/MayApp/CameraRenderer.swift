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
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat, commandQueue: MTLCommandQueue){
        
        // Make camera
        camera = Camera(device: library.device)
        
        // Make uniforms
        cameraUpdateVertexUniforms = CameraUpdateVertexUniforms(projectionMatrix: float4x4())
        
        // Make square mesh
        squareMesh = SquareMesh (device: library.device)
        
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
    
    public func updateCameraTexture(with colorbuffer: [Camera.RGBA]) {
        
        // Copy color_buffer into texture
        colorbuffer.withUnsafeBytes { body in
            //Bytes per row should be width for 2D textures
            camera.texture.replace(region: MTLRegionMake2D(0, 0, Camera.width, Camera.height), mipmapLevel: 0, withBytes: body.baseAddress!, bytesPerRow: Camera.width * MemoryLayout<Camera.RGBA>.stride)
        }
        
        let floatbuffer = colorbuffer.map{ (rgba) -> Camera.RGBAF in
            let output=Camera.RGBAF(r: rgba.r, g: rgba.g, b: rgba.b, a: rgba.a)
            return output
        }
        
        floatbuffer.withUnsafeBytes{ body in
            camera.textureFloat.replace(region: MTLRegionMake2D(0, 0, Camera.width, Camera.height),
                mipmapLevel:0, withBytes: body.baseAddress!, bytesPerRow: Camera.width * MemoryLayout<Camera.RGBAF>.stride)
        }

        //public init?(mtlTexture texture: MTLTexture, options: [String : Any]? = nil)
        

        
    }
    public func tagDetectionAndPoseEsimtation(with depthbuffer: [Camera.Depth], from pose: Pose) -> [String] {
        
        var messageCollection = [String]()
        let cameraFrame = CIImage(mtlTexture: camera.textureFloat)!
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
                boundLocation[0] = ((Int(feature.bottomLeft.y)) * Camera.width + (Int(feature.bottomLeft.x)))
                boundLocation[1] = ((Int(feature.bottomRight.y)) * Camera.width + (Int(feature.bottomRight.x)))
                boundLocation[2] = ((Int(feature.topLeft.y)) * Camera.width + (Int(feature.topLeft.x)))
                boundLocation[3] = ((Int(feature.topRight.y)) * Camera.width + (Int(feature.topRight.x)))
                
                let centerY = (Int(feature.bottomLeft.y) + Int(feature.topRight.y))/2
                let centerX = (Int(feature.bottomLeft.x) + Int(feature.topRight.x))/2
                let centerLocation = centerY * Camera.width + centerX
                
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
        
        commandEncoder.setFragmentTexture(camera.textureFloat, at: 0)
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: squareMesh.vertexCount)
    }
}
