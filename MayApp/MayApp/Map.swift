//
//  Map.swift
//  MayApp
//
//  Created by Russell Ladd on 2/20/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal

final class Map {
    
    // Maximum texture size on A9 GPU is 16384, but A7 and A8 is only 8192
    // Mac supports 16384
    
    static let texels = 8192
    static let meters: Float = 20.0
    
    static let texelsPerMeter: Float = Float(texels) / meters
    
    static let textureDescriptor: MTLTextureDescriptor = {
        
        // Texture values will be in [-1.0, 1.0] where -1.0 is free and 1.0 is occupied
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Snorm, width: Map.texels, height: Map.texels, mipmapped: false)
        textureDescriptor.storageMode = .private
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        return textureDescriptor
    }()
    
    let texture: MTLTexture
    
    init(device: MTLDevice) {
        
        texture = device.makeTexture(descriptor: Map.textureDescriptor)
        texture.label = "Map Texture"
    }
}
