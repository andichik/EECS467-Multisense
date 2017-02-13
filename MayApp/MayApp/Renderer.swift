//
//  Renderer.swift
//  MayApp
//
//  Created by Russell Ladd on 2/5/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import Metal
import MetalKit

final class Renderer: NSObject, MTKViewDelegate {
    
    let library: MTLLibrary
    
    let commandQueue: MTLCommandQueue
    
    let laserDistanceRenderer: LaserDistanceRenderer
    
    init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        
        self.library = device.newDefaultLibrary()!
        
        self.commandQueue = device.makeCommandQueue()
        
        self.laserDistanceRenderer = LaserDistanceRenderer(library: library, pixelFormat: pixelFormat)
        
        super.init()
    }
    
    var aspectRatioMatrix = float4x4(1.0)
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
        if size.width < size.height {
            aspectRatioMatrix = float4x4(scaleX: 1.0, scaleY: Float(size.width / size.height))
        } else {
            aspectRatioMatrix = float4x4(scaleX: Float(size.height / size.width), scaleY: 1.0)
        }
    }
    
    func draw(in view: MTKView) {
        
        guard view.drawableSize.width * view.drawableSize.height != 0.0  else {
            return
        }
        
        guard let currentRenderPassDescriptor = view.currentRenderPassDescriptor, let currentDrawable = view.currentDrawable else {
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
        
        let scaleMatrix = float4x4(scaleX: 0.8, scaleY: 0.8)
        
        laserDistanceRenderer.draw(with: commandEncoder, projectionMatrix: scaleMatrix * aspectRatioMatrix)
        
        commandEncoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
