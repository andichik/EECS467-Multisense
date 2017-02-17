//
//  MapRenderer.swift
//  MayApp
//
//  Created by Russell Ladd on 2/15/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import simd

public final class MapRenderer {
    
    let mapTexelsPerMeter: Float
    
    let mapTexture: MTLTexture
    
    let mapUpdatePipeline: MTLComputePipelineState
    
    init(library: MTLLibrary, pixelFormat: MTLPixelFormat) {
        
        // Calculate metrics
        
        // Maximum texture size on A9 GPU is 16384, but A7 and A8 is only 8192
        // Mac supports 16384
        let mapTexels = 8192
        
        let mapMeters: Float = 20.0
        
        mapTexelsPerMeter = Float(mapTexels) / mapMeters
        
        // Make texture
        
        let mapTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float, width: mapTexels, height: mapTexels, mipmapped: false)
        
        mapTexture = library.device.makeTexture(descriptor: mapTextureDescriptor)
        
        // Make pipeline
        
        let mapUpdateFunction = library.makeFunction(name: "updateMap")!
        
        mapUpdatePipeline = try! library.device.makeComputePipelineState(function: mapUpdateFunction)
    }
}
