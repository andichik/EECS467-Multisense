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
    
    let samples: [(Float, Float)] = [
        (Float(M_PI * -0.75), 0.5),
        (Float(M_PI * -0.50), 0.75),
        (Float(M_PI * -0.25), 0.5),
        (Float(M_PI *  0.00), 1.0),
        (Float(M_PI *  0.25), 0.75),
        (Float(M_PI *  0.50), 0.25),
        (Float(M_PI *  0.75), 0.5),
    ]
    
    init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        
        self.library = device.newDefaultLibrary()!
        
        self.commandQueue = device.makeCommandQueue()
        
        self.laserDistanceRenderer = LaserDistanceRenderer(library: library, pixelFormat: pixelFormat, mesh: LaserDistanceMesh(device: device, sampleCount: 1081))
        
        //self.laserDistanceRenderer.laserDistanceMesh.store(samples: samples)
        
        super.init()
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
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
        
        let aspectRatioMatrix: float4x4
        if view.drawableSize.width < view.drawableSize.height {
            aspectRatioMatrix = float4x4(scaleX: 1.0, scaleY: Float(view.drawableSize.width / view.drawableSize.height))
        } else {
            aspectRatioMatrix = float4x4(scaleX: Float(view.drawableSize.height / view.drawableSize.width), scaleY: 1.0)
        }
        
        laserDistanceRenderer.uniforms.projectionMatrix = float4x4(scaleX: 0.8, scaleY: 0.8) * aspectRatioMatrix
        laserDistanceRenderer.draw(with: commandEncoder)
        
        commandEncoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
}
