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
    
    static let width = 640 // 1280
    static let height = 480 // 1024
    
    static let points = width * height
    
    public struct Color {
        public let r: UInt8
        public let g: UInt8
        public let b: UInt8
    }
    
    public struct RGBA {
        let r: UInt8
        let g: UInt8
        let b: UInt8
        let a: UInt8
        
        public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
            self.r = r
            self.g = g
            self.b = b
            self.a = a
        }
    }
    
    public struct RGBAF {
        let r: Float32
        let g: Float32
        let b: Float32
        let a: Float32
        
        public init(r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
            self.r = Float32(r) / 255
            self.g = Float32(g) / 255
            self.b = Float32(b) / 255
            self.a = Float32(a) / 255
        }
    }
    
    

    
    
    public typealias Depth = UInt16
    
    static let pixelFormat = MTLPixelFormat.rgba8Uint
    static let pixelFormat2 = MTLPixelFormat.rgba32Float
    
    
    static let textureDescriptor: MTLTextureDescriptor = {
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: width, height: height, mipmapped: false)
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.shaderRead]
        return textureDescriptor
    }()
    
    static let textureDescriptor2: MTLTextureDescriptor = {
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat2, width: width, height: height, mipmapped: false)
        textureDescriptor.storageMode = .shared
        textureDescriptor.usage = [.shaderRead]
        return textureDescriptor
    }()
    
    
    let texture: MTLTexture
    let textureFloat: MTLTexture
    
    init(device: MTLDevice) {
        
        texture = device.makeTexture(descriptor: Camera.textureDescriptor)
        texture.label = "Camera Texture"
        
        textureFloat = device.makeTexture(descriptor: Camera.textureDescriptor2)
        textureFloat.label = "Camera Texture Float"
    }
}
