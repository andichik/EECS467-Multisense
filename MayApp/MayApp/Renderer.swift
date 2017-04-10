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
    public let curvatureRenderer: CurvatureRenderer
    public let mapRenderer: MapRenderer
    public let vectorMapRenderer: VectorMapRenderer
    public let poseRenderer: PoseRenderer
    public let particleRenderer: ParticleRenderer
    public let cameraRenderer: CameraRenderer
    public let pointCloudRender: PointCloudRenderer
    
    public enum Content: Int {
        case vision
        case map
        case vectorMap
        case camera
        case pointcloud
    }
    
    public var content = Content.vision
    
    var aspectRatio: Float = 1.0
    
    public struct SceneCamera {
        
        private(set) var matrix = float4x4(angle: .pi / 2.0)
        
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
    
    public var visionCamera = SceneCamera()
    public var mapCamera = SceneCamera()
    
    public init(device: MTLDevice, pixelFormat: MTLPixelFormat) {
        
        self.library = try! device.makeDefaultLibrary(bundle: Bundle(identifier: "com.EECS467.MayAppCommon")!)
        
        self.commandQueue = device.makeCommandQueue()
        
        self.laserDistanceRenderer = LaserDistanceRenderer(library: library, pixelFormat: pixelFormat)
        self.odometryRenderer = OdometryRenderer(library: library, pixelFormat: pixelFormat)
        self.curvatureRenderer = CurvatureRenderer(library: library, pixelFormat: pixelFormat)
        self.mapRenderer = MapRenderer(library: library, pixelFormat: pixelFormat, commandQueue: commandQueue)
        self.vectorMapRenderer = VectorMapRenderer(library: library, pixelFormat: pixelFormat)
        self.poseRenderer = PoseRenderer(library: library, pixelFormat: pixelFormat)
        self.particleRenderer = ParticleRenderer(library: library, pixelFormat: pixelFormat, commandQueue: commandQueue)
        self.cameraRenderer = CameraRenderer(library: library, pixelFormat: pixelFormat, commandQueue: commandQueue)
        self.pointCloudRender = PointCloudRenderer(library: library, pixelFormat: pixelFormat, commandQueue: commandQueue)
        
        super.init()
    }
    
    public func updateParticlesAndMap(odometryDelta: Odometry.Delta, laserDistances: [UInt16], completionHandler: @escaping (_ bestPose: Pose) -> Void) {
        
        // Use current laser distances for particle weighting and map update
        laserDistanceRenderer.updateMesh(with: laserDistances)
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        particleRenderer.resampleParticles(commandBuffer: commandBuffer)
        particleRenderer.particleBufferRing.rotate()
        
        particleRenderer.moveAndWeighParticles(commandBuffer: commandBuffer, odometryDelta: odometryDelta, mapTexture: mapRenderer.map.texture, laserDistancesBuffer: laserDistanceRenderer.laserDistanceMesh.vertexBuffer) { bestPose in
            
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
    
    public func updateVectorMap(odometryDelta: Odometry.Delta, laserDistances: [UInt16], completionHandler: @escaping (_ bestPose: Pose) -> Void) {
        
        laserDistanceRenderer.updateMesh(with: laserDistances)
        
        // Guess next pose based purely on odometry
        let nextPoseFromOdometry = poseRenderer.pose.applying(delta: odometryDelta)
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        curvatureRenderer.calculateCurvature(commandBuffer: commandBuffer, laserDistancesBuffer: self.laserDistanceRenderer.laserDistanceMesh.vertexBuffer) { mapPoints in
            
            // Convert points from robot frame to world frame according to guessed pose
            let mapPointsFromPose = mapPoints.map { $0.applying(transform: nextPoseFromOdometry.matrix) }
            
            let correction = self.vectorMapRenderer.correctAndMergePoints(mapPointsFromPose)
            
            let correctedPose = nextPoseFromOdometry.applying(transform: correction)
            
            self.poseRenderer.pose = correctedPose
        }
        
        commandBuffer.commit()
    }
    
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
        aspectRatio = Float(size.width / size.height)
    }
    
    public func draw(in view: MTKView) {
        
        guard view.drawableSize.width * view.drawableSize.height != 0.0  else {
            return
        }
        
        guard let currentRenderPassDescriptor = view.currentRenderPassDescriptor, let currentDrawable = view.currentDrawable else {
            return
        }
        
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        let aspectRatioMatrix: float4x4;
        if aspectRatio < 1.0 {
            aspectRatioMatrix = float4x4(scaleX: 1.0, scaleY: aspectRatio)
        } else {
            aspectRatioMatrix = float4x4(scaleX: 1.0 / aspectRatio, scaleY: 1.0)
        }
        
        let projectionMatrix = aspectRatioMatrix
        
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
        
        switch content {
            
        case .vision:
            let viewProjectionMatrix = projectionMatrix * visionCamera.matrix
            
            laserDistanceRenderer.draw(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            odometryRenderer.draw(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            
            curvatureRenderer.renderCorners(commandEncoder: commandEncoder, commandBuffer: commandBuffer, projectionMatrix: viewProjectionMatrix, laserDistancesBuffer: laserDistanceRenderer.laserDistanceMesh.vertexBuffer)
            
        case .map:
            let viewProjectionMatrix = projectionMatrix * mapCamera.matrix
            
            mapRenderer.renderMap(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            particleRenderer.renderParticles(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            
            let vectorViewProjectionMatrix = projectionMatrix * mapCamera.matrix * Map.textureScaleMatrix
            
            vectorMapRenderer.renderPoints(with: commandEncoder, projectionMatrix: vectorViewProjectionMatrix)
            vectorMapRenderer.renderConnections(with: commandEncoder, projectionMatrix: vectorViewProjectionMatrix)
            
        case .vectorMap:
            let viewProjectionMatrix = projectionMatrix * mapCamera.matrix
            let vectorViewProjectionMatrix = projectionMatrix * mapCamera.matrix * Map.textureScaleMatrix
            
            vectorMapRenderer.renderPoints(with: commandEncoder, projectionMatrix: vectorViewProjectionMatrix)
            vectorMapRenderer.renderConnections(with: commandEncoder, projectionMatrix: vectorViewProjectionMatrix)
            
            poseRenderer.renderPose(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            
        case .camera:
            cameraRenderer.renderCamera(with: commandEncoder, projectionMatrix: projectionMatrix)
            
        case .pointcloud:
            pointCloudRender.renderPointcloud(with: commandEncoder, aspectRatio: aspectRatio, camera: cameraRenderer.camera)
        }
        
        commandEncoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    public func reset() {
        
        visionCamera = SceneCamera()
        mapCamera = SceneCamera()
        
        odometryRenderer.reset()
        mapRenderer.reset()
        vectorMapRenderer.reset()
        poseRenderer.reset()
        particleRenderer.resetParticles()
    }
}
