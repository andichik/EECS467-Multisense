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
    
    public let laserDistancesTexture: MTLTexture
    
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
        
        // Make laser distance texture
        
        let laserDistancesTextureDescriptor = MTLTextureDescriptor()
        laserDistancesTextureDescriptor.textureType = .type1D
        laserDistancesTextureDescriptor.pixelFormat = .r16Uint
        laserDistancesTextureDescriptor.width = Laser.sampleCount
        laserDistancesTextureDescriptor.storageMode = .shared
        laserDistancesTextureDescriptor.usage = .shaderRead
        
        laserDistancesTexture = library.device.makeTexture(descriptor: laserDistancesTextureDescriptor)
        
        // Initialize particle filter
        
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
            
            commandBuffer.addCompletedHandler { _ in
                DispatchQueue.main.async {
                    self.isWorking = false
                }
            }
            
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
            
        case .map:
            mapRenderer.updateMap(commandBuffer: commandBuffer, laserDistanceMesh: laserDistanceRenderer.laserDistanceMesh)
            particleRenderer.updateParticles(commandBuffer: commandBuffer, mapTexture: mapRenderer.map.texture, laserDistancesTexture: laserDistancesTexture)
            
            particleRenderer.particleBufferRing.rotate()
            
            commandBuffer.addCompletedHandler { _ in
                DispatchQueue.main.async {
                    
                    let commandBuffer = self.commandQueue.makeCommandBuffer()
                    
                    self.particleRenderer.resampleParticles(commandBuffer: commandBuffer)
                    
                    self.particleRenderer.particleBufferRing.rotate()
                    
                    let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
                    
                    self.mapRenderer.renderMap(with: commandEncoder, projectionMatrix: projectionMatrix)
                    self.particleRenderer.renderParticles(with: commandEncoder, projectionMatrix: projectionMatrix)
                    
                    commandEncoder.endEncoding()
                    
                    commandBuffer.addCompletedHandler { _ in
                        DispatchQueue.main.async {
                            self.isWorking = false
                        }
                    }
                    
                    commandBuffer.present(currentDrawable)
                    commandBuffer.commit()
                }
            }
            
            commandBuffer.commit()
        }
    }
    
    public func updateLaserDistancesTexture(with distances: [Int]) {
        
        guard distances.count == laserDistancesTexture.width else {
            print("Unexpected number of laser distances: \(distances.count)")
            return
        }
        
        let unsignedDistances = distances.map { UInt16($0) }
        
        // Copy distances into texture
        unsignedDistances.withUnsafeBytes { body in
            // Bytes per row should be 0 for 1D textures
            laserDistancesTexture.replace(region: MTLRegionMake1D(0, distances.count), mipmapLevel: 0, withBytes: body.baseAddress!, bytesPerRow: 0)
        }
    }
    
    public func reset() {
        
        odometryRenderer.reset()
        
        // TODO: Reset map
        particleRenderer.resetParticles()
    }
}
