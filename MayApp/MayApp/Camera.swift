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
    
    public struct Quality {
        
        public let width: Int
        public let height: Int
        
        public let points: Int
        
        public init(width: Int, height: Int) {
            
            self.width = width
            self.height = height
            
            self.points = width * height
        }
        
        public static let medium = Quality(width: 640, height: 480)
        public static let high = Quality(width: 1280, height: 1024)
    }
    
    public struct Color {
        
        public init(r: UInt8, g: UInt8, b: UInt8) {
            self.r = r
            self.g = g
            self.b = b
        }
        
        public let r: UInt8
        public let g: UInt8
        public let b: UInt8
    }
    
    public typealias Depth = UInt16
    
    static let pixelFormat = MTLPixelFormat.rgba32Float
    
    let texture: MTLTexture
    
    let quality: Quality
    
    init(device: MTLDevice, quality: Quality) {
        
        self.quality = quality
        
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Camera.pixelFormat, width: quality.width, height: quality.height, mipmapped: false)
        #if os(iOS)
            textureDescriptor.storageMode = .shared
        #elseif os(macOS)
            textureDescriptor.storageMode = .managed
        #endif
        textureDescriptor.usage = [.shaderRead]
        
        texture = device.makeTexture(descriptor: textureDescriptor)
        texture.label = "Camera Texture"
    }
}
