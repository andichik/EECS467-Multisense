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
    public let pathRenderer: PathRenderer
    
    public enum Content: Int {
        case vision
        case map
        case vectorMap
        case camera
        case pointcloud
        case path
    }
    
    public var content = Content.vision
    
    var aspectRatio: Float = 1.0
    
    var aspectRatioMatrix: float4x4 {
        
        if aspectRatio < 1.0 {
            return float4x4(scaleX: 1.0, scaleY: aspectRatio)
        } else {
            return float4x4(scaleX: 1.0 / aspectRatio, scaleY: 1.0)
        }
    }
    
    public struct SceneCamera {
        
        public private(set) var matrix = float4x4(angle: .pi / 2.0)
        
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
        self.pathRenderer = PathRenderer(library: library, pixelFormat: pixelFormat, commandQueue: commandQueue)
        
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
    
    public func updateVectorMap(odometryDelta: Odometry.Delta, laserDistances: [UInt16], completionHandler: @escaping (_ bestPose: Pose, _ mapPoints: [UUID: MapPoint]) -> Void) {
        
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
            
            completionHandler(correctedPose, self.vectorMapRenderer.pointDictionary)
        }
        
        commandBuffer.commit()
    }
    
    public func resolveWorld(pointDictionaryRemote: [UUID: MapPoint]) -> (float2, float2x2)? {
        var points = [MapPoint]()
        
        for (_, value) in pointDictionaryRemote {
            points.append(value)
        }
        
        if let ((translation, rotation, _), _) = vectorMapRenderer.correctPoints(points) {
            return (translation, rotation)
        }
        else {
            return nil
        }
    }
    
    public func updateVectorMapFromRemote(mapPointsFromRemote: [UUID: MapPoint]) {
        //let correction = self.vectorMapRenderer.correctAndMergePoints(mapPointsFromRemote)
        print("IN UPDATE VECTOR MAP FROM REMOTE")
        
        let points = mapPointsFromRemote.map{ (key, value) -> MapPoint in
            return value
        }
        
        if let (_, assignments) = vectorMapRenderer.correctPoints(points) {
            vectorMapRenderer.mergePoints(points, assignments: assignments)
        }
    }
    
    public func findPath(destination: float2, algorithm: String) {
        let commandBuffer = commandQueue.makeCommandBuffer()
        
        // Generate Down scaled map
        pathRenderer.scaleDownMap(commandBuffer: commandBuffer, map: mapRenderer.map) // TODO: variable scale factor
        commandBuffer.commit()
//        commandBuffer.waitUntilCompleted()
        
        // Generate Path
        pathRenderer.makePath(bestPose: particleRenderer.bestPose, algorithm: algorithm, destination: destination)
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
        
        let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor)
        
        switch content {
            
        case .vision:
            let viewProjectionMatrix = aspectRatioMatrix * visionCamera.matrix
            
            laserDistanceRenderer.draw(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            odometryRenderer.draw(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            
            curvatureRenderer.renderCorners(commandEncoder: commandEncoder, commandBuffer: commandBuffer, projectionMatrix: viewProjectionMatrix, laserDistancesBuffer: laserDistanceRenderer.laserDistanceMesh.vertexBuffer)
            
        case .map:
            let viewProjectionMatrix = aspectRatioMatrix * mapCamera.matrix
            
            mapRenderer.renderMap(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            particleRenderer.renderParticles(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            
            
            
            let vectorViewProjectionMatrix = aspectRatioMatrix * mapCamera.matrix * Map.textureScaleMatrix
            
            vectorMapRenderer.renderPoints(with: commandEncoder, projectionMatrix: vectorViewProjectionMatrix)
            vectorMapRenderer.renderConnections(with: commandEncoder, projectionMatrix: vectorViewProjectionMatrix)
            
        case .vectorMap:
            let vectorViewProjectionMatrix = aspectRatioMatrix * mapCamera.matrix * Map.textureScaleMatrix
            
            vectorMapRenderer.renderPoints(with: commandEncoder, projectionMatrix: vectorViewProjectionMatrix)
            vectorMapRenderer.renderConnections(with: commandEncoder, projectionMatrix: vectorViewProjectionMatrix)
            
            let viewProjectionMatrix = aspectRatioMatrix * mapCamera.matrix
            
            pathRenderer.drawPath(with: commandEncoder, projectionMatrix: vectorViewProjectionMatrix)
            
            poseRenderer.renderPose(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            
        case .camera:
            cameraRenderer.renderCamera(with: commandEncoder, projectionMatrix: aspectRatioMatrix)
            
        case .pointcloud:
            pointCloudRender.renderPointcloud(with: commandEncoder, aspectRatio: aspectRatio, camera: cameraRenderer.camera)
            
        case .path:
            let viewProjectionMatrix = aspectRatioMatrix * mapCamera.matrix
            pathRenderer.drawMap(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
            pathRenderer.drawPath(with: commandEncoder, projectionMatrix: viewProjectionMatrix)
        }
        
        commandEncoder.endEncoding()
        
        commandBuffer.present(currentDrawable)
        commandBuffer.commit()
    }
    
    public func project(_ point: float4) -> float4 {
        
        return aspectRatioMatrix * mapCamera.matrix * Map.textureScaleMatrix * point
    }
    
    public func unproject(_ point: float4) -> float4 {
        
        let projectionMatrix = aspectRatioMatrix * mapCamera.matrix * Map.textureScaleMatrix
        
        return projectionMatrix.inverse * point
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
