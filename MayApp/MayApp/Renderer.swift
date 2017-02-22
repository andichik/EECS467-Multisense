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

public final class Renderer: NSObject, MTKViewDelegate {
    
    let library: MTLLibrary
    
    let commandQueue: MTLCommandQueue
    
    public let laserDistanceRenderer: LaserDistanceRenderer
    public let odometryRenderer: OdometryRenderer
    public let mapRenderer: MapRenderer
    public let particleRenderer: ParticleRenderer
    
    public enum Content: Int {
        case vision
        case map
    }
    
    public var content = Content.vision
    
    public var isWorking = false
    
    public init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        
        self.library = try! device.makeDefaultLibrary(bundle: Bundle(identifier: "com.EECS467.MayAppCommon")!)
        
        self.commandQueue = device.makeCommandQueue()
        
        self.laserDistanceRenderer = LaserDistanceRenderer(library: library, pixelFormat: pixelFormat)
        self.odometryRenderer = OdometryRenderer(library: library, pixelFormat: pixelFormat)
        self.mapRenderer = MapRenderer(library: library, pixelFormat: pixelFormat)
        self.particleRenderer = ParticleRenderer(library: library, pixelFormat: pixelFormat, commandQueue: commandQueue)
        
        particleRenderer.resetParticles()
        
        super.init()
    }
    
    var aspectRatioMatrix = float4x4(1.0)
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
        if size.width < size.height {
            aspectRatioMatrix = float4x4(scaleX: 1.0, scaleY: Float(size.width / size.height))
        } else {
            aspectRatioMatrix = float4x4(scaleX: Float(size.height / size.width), scaleY: 1.0)
        }
    }
    
    public func draw(in view: MTKView) {
        
        guard view.drawableSize.width * view.drawableSize.height != 0.0  else {
            return
        }
        
        guard let currentRenderPassDescriptor = view.currentRenderPassDescriptor, let currentDrawable = view.currentDrawable else {
            return
        }
        
        isWorking = true
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        let projectionMatrix = aspectRatioMatrix * float4x4(angle: Float(M_PI_2))
        
        switch content {
            
        case .vision:
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
            
            let scale = 1.0 / Laser.maximumDistance
            let scaleMatrix = float4x4(scaleX: scale, scaleY: scale)
            
            laserDistanceRenderer.draw(with: commandEncoder, projectionMatrix: scaleMatrix * projectionMatrix)
            odometryRenderer.draw(with: commandEncoder, projectionMatrix: scaleMatrix * projectionMatrix)
            
            commandEncoder.endEncoding()
            
        case .map:
            mapRenderer.updateMap(commandBuffer: commandBuffer)
            particleRenderer.updateParticles(commandBuffer: commandBuffer)
            
            let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
            
            mapRenderer.renderMap(with: commandEncoder, projectionMatrix: projectionMatrix)
            particleRenderer.renderParticles(with: commandEncoder, projectionMatrix: projectionMatrix)
            
            commandEncoder.endEncoding()
            
            mapRenderer.mapRing.rotate()
        }
        
        commandBuffer.addCompletedHandler { _ in
            DispatchQueue.main.async {
                self.isWorking = false
            }
        }
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    public func reset() {
        
        odometryRenderer.reset()
        
        // TODO: Reset map
        particleRenderer.resetParticles()
    }
}
