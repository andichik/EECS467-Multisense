//
//  Map.swift
//  MayApp
//
//  Created by Russell Ladd on 2/20/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

public final class Camera {
    
    // Maximum texture size on A9 GPU is 16384, but A7 and A8 is only 8192
    // Mac supports 16384
    
    //static let texels = 8192
    static let meters: Float = 5.0
    static let width = 640
    static let height = 480
    
    public struct Color{
        let r: UInt8
        let g: UInt8
        let b: UInt8
    }
    public struct RGBA{
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
    }
    
    //static let texelsPerMeter = Float(texels) / meters
    
    //static var textureScaleMatrix = float4x4(diagonal: float4(2.0 / meters, 2.0 / meters, 1.0, 1.0))
    
    static let pixelFormat = MTLPixelFormat.r16Snorm
    
    static let textureDescriptor: MTLTextureDescriptor = {
        
        // Texture values will be in [-1.0, 1.0] where -1.0 is free and 1.0 is occupied
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        textureDescriptor.storageMode = .private
        textureDescriptor.usage = [.shaderRead, .renderTarget]
        return textureDescriptor
    }()
    
    let texture: MTLTexture
    
    init(device: MTLDevice) {
        
        texture = device.makeTexture(descriptor: Camera.textureDescriptor)
        texture.label = "Camera Texture"
    }
}
