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
    
    public struct Camera {
        
        private(set) var matrix = float4x4(angle: Float(M_PI_2))
        
        private mutating func apply(transform: float4x4) {
            matrix = transform * matrix
        }
        
        private mutating func apply(transform: float4x4, about point: float2) {
            
            let translation = float3(point.x, point.y, 0.0)
            
            apply(transform: float4x4(translation: translation) * transform * float4x4(translation: -translation))
        }
        
        public mutating func translate(by translation: float2) {
            apply(transform: float4x4(translation: float4(translation.x, translation.y, 0.0, 1.0)))
        }
        
        public mutating func zoom(by zoom: Float, about point: float2) {
            apply(transform: float4x4(diagonal: float4(zoom, zoom, 1.0, 1.0)), about: point)
        }
        
        public mutating func rotate(by angle: Float, about point: float2) {
            apply(transform: float4x4(angle: angle), about: point)
        }
    }
    
    public var camera = Camera()
    
    var aspectRatioMatrix = float4x4(1.0)
    
    public init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        
        self.library = try! device.makeDefaultLibrary(bundle: Bundle(identifier: "com.EECS467.MayAppCommon")!)
        
        self.commandQueue = device.makeCommandQueue()
        
        self.laserDistanceRenderer = LaserDistanceRenderer(library: library, pixelFormat: pixelFormat)
        self.odometryRenderer = OdometryRenderer(library: library, pixelFormat: pixelFormat)
        self.mapRenderer = MapRenderer(library: library, pixelFormat: pixelFormat, commandQueue: commandQueue)
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
    
    public func updateParticlesAndMap(odometryDelta: Odometry.Delta, laserDistances: [Int], completionHandler: @escaping (_ bestPose: Pose) -> Void) {
        
        //TODO: only update laser distance once
        // Use current laser distances for particle weighting and map update
        updateLaserDistancesTexture(with: laserDistances)
        laserDistanceRenderer.updateMesh(with: laserDistances)
        
        guard content == .map else {
            
            // FIXME: This is only here to make it work
            // TODO: Get rid of map mode
            completionHandler(Pose())
            
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        particleRenderer.resampleParticles(commandBuffer: commandBuffer)
        particleRenderer.particleBufferRing.rotate()
        
        particleRenderer.moveAndWeighParticles(commandBuffer: commandBuffer, odometryDelta: odometryDelta, mapTexture: mapRenderer.map.texture, laserDistancesTexture: laserDistancesTexture) { bestPose in
            
            let commandBuffer = self.commandQueue.makeCommandBuffer()
            
            self.mapRenderer.updateMap(commandBuffer: commandBuffer, pose: bestPose, laserDistanceMesh: self.laserDistanceRenderer.laserDistanceMesh)
            
            commandBuffer.commit()
            
            DispatchQueue.main.async {
                completionHandler(bestPose)
            }
        }
        
        particleRenderer.particleBufferRing.rotate()
        
        commandBuffer.commit()
    }
    
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
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        let projectionMatrix = aspectRatioMatrix
        
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
        
        switch content {
            
        case .vision:
            let scale = 1.0 / Laser.maximumDistance
            let scaleMatrix = float4x4(scaleX: scale, scaleY: scale)
            
            let viewProjectionMatrix = scaleMatrix * projectionMatrix
            
            laserDistanceRenderer.draw(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            odometryRenderer.draw(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            
        case .map:
            let viewProjectionMatrix = projectionMatrix * camera.matrix
            
            mapRenderer.renderMap(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            particleRenderer.renderParticles(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
        }
        
        commandEncoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
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
        
        camera = Camera()
        
        odometryRenderer.reset()
        mapRenderer.reset()
        particleRenderer.resetParticles()
    }
}
