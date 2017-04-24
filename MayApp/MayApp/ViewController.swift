//
//  ViewController.swift
//  MayApp
//
//  Created by Russell Ladd on 1/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Cocoa
import MultipeerConnectivity
import MayAppCommon
import Metal
import MetalKit
import simd

class MacViewController: NSViewController, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    
    // MARK: - Model
    
    let arduinoController = ArduinoController()
    let laserController = LaserController()
    let cameraController = CameraController()
    
    let mortorController = MotorController()
    
    let odometry = Odometry()
    
    var isAutonomous = false
    
    var prevPose = Pose()
    
    // MARK: - Rendering
    
    let device = MTLCreateSystemDefaultDevice()
    var metalView: MTKView!
    
    let pixelFormat = MTLPixelFormat.rgba16Float
    
    let renderer: Renderer?
    
    // MARK: - Networking
    
    let browser = MCNearbyServiceBrowser(peer: MCPeerID.shared, serviceType: Service.name)
    
    let robotSession1: MCSession
    let remoteSession1: MCSession
    
    enum DiscoveryInfo {
        static let key = "robot"
        static let value = "true"
    }
    
    enum InvitationContext {
        static let data = "robot".data(using: .utf8)!
    }
    
    let advertiser: MCNearbyServiceAdvertiser
    
    var savedRobotPeer = SavedPeer(key: "robotPeer")
    var savedRemotePeer = SavedPeer(key: "remotePeer")
    
    var resolvedWorld = false
    var originalTransformToWorld: (float2, float2x2, float4x4)?
    var networkingUUID = UUID()
    
    var isConnectedToRobot: Bool {
        return !robotSession1.connectedPeers.isEmpty
    }
    
    var isConnectedToRemote: Bool {
        return !remoteSession1.connectedPeers.isEmpty
    }
    
    // MARK: - Initialization
    
    required init?(coder: NSCoder) {
        
        robotSession1 = MCSession(peer: MCPeerID.shared)
        remoteSession1 = MCSession(peer: MCPeerID.shared)
        
        advertiser = MCNearbyServiceAdvertiser(peer: MCPeerID.shared, discoveryInfo: [DiscoveryInfo.key : DiscoveryInfo.value], serviceType: Service.name)
        
        if let device = device {
            renderer = Renderer(device: device, pixelFormat: pixelFormat, cameraQuality: .medium)
        } else {
            renderer = nil
        }
        
        super.init(coder: coder)
        
        advertiser.delegate = self
        robotSession1.delegate = self
        remoteSession1.delegate = self
        
        browser.delegate = self
    }
    
    // MARK: - View life cycle
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        browser.startBrowsingForPeers()
        
        advertiser.startAdvertisingPeer()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        browser.stopBrowsingForPeers()
        
        advertiser.stopAdvertisingPeer()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Add metal view
        
        metalView = MTKView(frame: view.bounds, device: device)
        metalView.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        metalView.colorPixelFormat = pixelFormat
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearDepth = 10.0
        metalView.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        metalView.delegate = renderer
        
        view.addSubview(metalView, positioned: .below, relativeTo: nil)
        
        // Start reading from sensors
        
        var sequenceNumber = 0
        
        laserController.measureContinuously(scanInterval: 0.1) { [unowned self] distances in
            
            let mediumCameraMeasurement = self.cameraController.measure(quality: .medium)
            //let highCameraMeasurement = self.cameraController.measure(quality: .high)
            
            // Create sensor measurement
            
            let sensorMeasurement = SensorMeasurement(sequenceNumber: sequenceNumber,
                                                      leftEncoder: self.arduinoController.encoderLeft,
                                                      rightEncoder: self.arduinoController.encoderRight,
                                                      laserDistances: distances,
                                                      cameraVideo: mediumCameraMeasurement.video.compressed(with: .lzfse)!,
                                                      cameraDepth: mediumCameraMeasurement.depth.compressed(with: .lzfse)!)
            
            // Send data to remote every tenth frame
            
            do {
                
                if sequenceNumber % 10 == 0 && self.isConnectedToRemote {
                    try self.remoteSession1.send(MessageType.serialize(sensorMeasurement), toPeers: self.remoteSession1.connectedPeers, with: .unreliable)
                    print("Sent \(sequenceNumber)")
                }
                
                sequenceNumber += 1
                
            } catch {
                
                print("Error \(error)")
            }
            
            // Only process locally if this device supports Metal
            
            guard let renderer = self.renderer else {
                return
            }
            
            // Compute delta
            
            let delta = self.odometry.computeDeltaForTicks(left: sensorMeasurement.leftEncoder, right: sensorMeasurement.rightEncoder)
            
            // Get laser distances
            
            let laserDistances = sensorMeasurement.laserDistances.withUnsafeBytes { (pointer: UnsafePointer<UInt16>) -> [UInt16] in
                let buffer = UnsafeBufferPointer(start: pointer, count: sensorMeasurement.laserDistances.count / MemoryLayout<UInt16>.stride)
                return Array(buffer)
            }
            
            // Get camera data
            
            let cameraData = mediumCameraMeasurement.video
            let cameraVideo = cameraData.withUnsafeBytes { (pointer: UnsafePointer<Camera.Color>) -> [Camera.Color] in
                let buffer = UnsafeBufferPointer(start: pointer, count: cameraData.count / MemoryLayout<Camera.Color>.stride)
                return Array(buffer)
            }
            
            // Get depth data
            
            let depthData = mediumCameraMeasurement.depth
            let cameraDepth = depthData.withUnsafeBytes { (pointer: UnsafePointer<Camera.Depth>) -> [Camera.Depth] in
                let buffer = UnsafeBufferPointer(start: pointer, count: depthData.count / MemoryLayout<Camera.Depth>.stride)
                return Array(buffer)
            }
            
            renderer.cameraRenderer.updateCameraTexture(with: cameraVideo)
            
            renderer.pointCloudRender.updatePointcloud(with: cameraDepth)
            
            /*renderer.updateParticlesAndMap(odometryDelta: delta, laserDistances: laserDistances, completionHandler: { bestPose in
             
             //self.updatePoseLabels(with: bestPose)
             
             renderer.odometryRenderer.updateMeshAndHead(with: bestPose)
             })*/
            
            renderer.updateVectorMap(odometryDelta: delta, laserDistances: laserDistances) { pose in
                
                DispatchQueue.main.async {
                    if self.isAutonomous {
                        //update the current pose from vector map
                        //update motor command
                        //detect a jump in pose
                        let dist = sqrt(pow(pose.position.x - self.prevPose.position.x,2) + pow(pose.position.y - self.prevPose.position.y,2))
                        if(dist > 1){
                            print("!!!!!!!JUMP!!!!!!!!!!")
                        }
                        print("current : \(pose.position), currentAngle: \(pose.angle)")
                        self.mortorController.handlePose(pose)
                        self.prevPose = pose
                        let velocity = self.mortorController.updateMotorCommand()
                        print("left velocity: \(velocity.0) right velocity: \(velocity.1)")
                        self.arduinoController.sendVel(velocity.0, velocity.1)
                    }
                }
            }
        }
        
        var mapUpdateSequenceNumber = 0
        
        // send map updates
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            
            guard let renderer = self.renderer else {
                return
            }
            
            if self.isConnectedToRobot {
                
//                let currentPosition = renderer.poseRenderer.pose.position.xy
//                let currentRotation = float2x2((self.renderer?.poseRenderer.pose.angle)!)
//                
//                var globalPosition: float2
//                var globalRotation: float2x2
//                
//                if let globeTransform = self.originalTransformToWorld {
//                    globalPosition = currentPosition! - globeTransform.0
//                    globalRotation = currentRotation - globeTransform.1
//                }
//                else {
//                    globalPosition = float2(x: 0.0, y: 0.0)
//                    globalRotation = float2x2(angle: 0.0)
//                }
                
                let pointDictionary = renderer.vectorMapRenderer.pointDictionary
                
                if !pointDictionary.isEmpty {
                    
                    // calculate global transform and apply to pointDictionary
                    mapUpdateSequenceNumber += 1
                    
                    let testTransform = float4x4(translation: float2(x: 1, y: 0.05)) * float4x4(angle: 0.1)
                    
                    var pointDict = [UUID: MapPoint]()
                    
                    // just for testing: apply additional transform of 1.0, 1.0, 0 degrees to simulate a new start position
                    for (key, value) in pointDictionary {
                        pointDict[key] = value.applying(transform: testTransform)
                    }
                    
                    if let transform = self.originalTransformToWorld?.2 {
                        for (key, value) in pointDictionary {
                            pointDict[key] = pointDict[key]?.applying(transform: transform)
                        }
                    }

                    
                    if let transformedPose = self.renderer?.poseRenderer.pose.applying(transform: self.originalTransformToWorld!.2) {
                        print("REMOTE transformed pose to send out \(transformedPose)")
                        let mapUpdate = MapUpdate(sequenceNumber: mapUpdateSequenceNumber, pointDictionary: pointDict, robotId: self.networkingUUID, pose: transformedPose)
                        
                        try? self.robotSession1.send(MessageType.serialize(mapUpdate), toPeers: self.robotSession1.connectedPeers, with: .unreliable)
                    }
                }
            }
        }
    }
    
    // MARK: - Browsing for robot, not remote, peers
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        print("Found Peer: \(peerID.displayName)")
        
        // otherwise check if remote iOS device using DiscoveryInfo
        if info?[DiscoveryInfo.key] == DiscoveryInfo.value {
            print("Found robot peer")
            browser.invitePeer(peerID, to: robotSession1, withContext: InvitationContext.data, timeout: 0.0)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
    }
    
    // MARK: - Advertiser delegate
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        if context == InvitationContext.data {
            invitationHandler(true, robotSession1)
        } else {
            invitationHandler(true, remoteSession1)
        }
    }
    
    // MARK: - Button actions
    
    @IBAction func startMotors(_ button: NSButton) {
        
        arduinoController.send(RobotCommand(leftMotorVelocity: 20, rightMotorVelocity: 20))
    }
    
    @IBAction func stopMotors(_ button: NSButton) {
        
        arduinoController.send(RobotCommand(leftMotorVelocity: 0, rightMotorVelocity: 0))
    }
    
    @IBOutlet weak var Kp: NSTextFieldCell!
    @IBOutlet weak var Ki: NSTextFieldCell!
    @IBOutlet weak var Kd: NSTextFieldCell!
    
    @IBOutlet weak var kpStraight: NSTextFieldCell!
    @IBOutlet weak var kdStraight: NSTextFieldCell!
    
    @IBOutlet weak var kiStraight: NSTextFieldCell!
    
    @IBAction func setPID(_ sender: Any) {
        
        let kpVal = Kp.floatValue
        let kiVal = Ki.floatValue
        let kdVal = Kd.floatValue
        
        print("turning pid value set to kp: \(kpVal) ki:\(kiVal) kd: \(kdVal) ")
        self.mortorController.setTurningController(10.0, 0.01, kdVal)
    }
    
    @IBAction func setPIDStraight(_ sender: Any) {
        
        let kpVal = kpStraight.floatValue
        let kiVal = kiStraight.floatValue
        let kdVal = kdStraight.floatValue
        
        print("straight pid value set to kp: \(kpVal) ki:\(kiVal) kd: \(kdVal) ")
        self.mortorController.setMovingController(5.0, kiVal, kdVal)
    }
    
    @IBAction func contentChanged(_ sender: NSSegmentedControl) {
        
        renderer?.content = Renderer.Content(rawValue: sender.selectedSegment)!
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        DispatchQueue.main.async {
            
            switch session {
            case self.remoteSession1:
                if session.connectedPeers.isEmpty {
                    self.arduinoController.send(RobotCommand(leftMotorVelocity: 0, rightMotorVelocity: 0))
                }
            case self.robotSession1:
                switch state {
                case .notConnected:
                    self.advertiser.startAdvertisingPeer()
                    self.browser.startBrowsingForPeers()
                    print("not connected to other remote")
                    
                case .connecting:
                    print("connecting to other remote")
                    
                case .connected:
                    print("connected to other remote")
                    self.savedRemotePeer.peer = peerID
                }
            default:
                break
            }
            
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        guard let item = MessageType.deserialize(data) else {
            return
        }
        
        DispatchQueue.main.async {
            
            print("REMOTE received message!")
            
            switch session {
            case self.remoteSession1:
                
                switch item {
                    
                case let robotCommand as RobotCommand:
                    
                    self.isAutonomous = robotCommand.isAutonomous
                    if robotCommand.isAutonomous {
                        //self.mortorController.handlePath(robotCommand.destination, robotCommand.destinationAngle)
                        
                        //self.mortorController.addSquare()
                        //                    self.mortorController.handleMotorCommand(robotCommand: robotCommand)
                        //                    let velocity = self.mortorController.updateMotorCommand()
                        //                    print("left velocity: \(velocity.0) right velocity: \(velocity.1)")
                        //                    self.arduinoController.sendVel(velocity.0, velocity.1)
                        
                        if let renderer = self.renderer {
                            
                            if robotCommand.destination.x != 0.0 && robotCommand.destination.y != 0.0 {
                                print("Receive destination location at x: \(robotCommand.destination.x), y: \(robotCommand.destination.y)")
                                
                                renderer.findPath(destination: robotCommand.destination, algorithm: "A*")
                                self.mortorController.handlePath(newRobotpath: renderer.pathRenderer.pathBuffer)
                            }
                        }
                        
                    } else {
                        self.arduinoController.send(robotCommand)
                    }
                    
                default: break
                }
                
            case self.robotSession1:
                print("REMOTE packet received from remote")
                // packet received from other robot/iDevice
                switch item {
                case let mapUpdate as MapUpdate:
                    print("REMOTE Received MapUpdate \(mapUpdate.sequenceNumber)") //\(mapUpdate)")
                    
                    // resolve world transform
                    if !self.resolvedWorld {
                        
                        // master/leader/primary
                        for (_, value) in mapUpdate.pointDictionary {
                            print("REMOTE sent \(value.position)")
                        }
//                        for (_, value) in self.pointDictionary {
//                            print("REMOTE current \(value.position)")
//                        }
                        
                        if true {
                            //if UUID.greater(lhs: self.networkingUUID, rhs: mapUpdate.robotId) {
                            // TODO: SWAP COMMENTED IF STATEMENT LINES ABOVE
                            print("REMOTE I am the master")
                            //if networkingUUID > mapUpdate.robotId {
                            
                            let replicaTransform = self.renderer?.resolveWorld(pointDictionaryRemote: mapUpdate.pointDictionary)
                            self.resolvedWorld = (replicaTransform != nil)
                            
                            print("REMOTE World resolved? \(self.resolvedWorld)")
                            
                            // transmit to slave/follower/replica if solved
                            if let transform = replicaTransform {
                                self.originalTransformToWorld = (float2, float2x2, float4x4)(float2(x: 0.0, y: 0.0), float2x2(diagonal: float2(1.0)), float4x4(diagonal: float4(1.0, 1.0, 1.0, 1.0)))
                                //self.originalTransformToWorld?.0 = float2(x: 0.0, y: 0.0)
                                //self.originalTransformToWorld?.1 = float2x2(diagonal: float2(1.0))
                                self.originalTransformToWorld?.2 = float4x4(diagonal: float4(1.0, 1.0, 1.0, 1.0))
                                let transformTransmit = TransformTransmit(transform: transform)
                                
                                if !transform.cmatrix.columns.0.x.isNaN  {
                                    
                                    print("REMOTE sent: \(transformTransmit)")
                                    
                                    try? self.robotSession1.send(MessageType.serialize(transformTransmit), toPeers: self.robotSession1.connectedPeers, with: .unreliable)
                                    
                                }
                                else {
                                    print("REMOTE not sending: \(transformTransmit)")
                                    self.resolvedWorld = false
                                }
                            }
                        }
                        // do nothing as a slave/follower/replica, other then wait for transmission of your transform to global from master/leader/primary
                    }
                    else {
                        
                        if let transform = self.originalTransformToWorld?.2 {
                            // calculate global transform and apply to imported pointDict
                            var pointDict = [UUID: MapPoint]()
                            for (key, value) in mapUpdate.pointDictionary {
                                pointDict[key] = value.applying(transform: transform)
                            }
                            
                            self.renderer?.poseRenderer.otherPose = mapUpdate.pose
                            print("REMOTE other robot pose: \(mapUpdate.pose)")
                            
                            self.renderer?.updateVectorMapFromRemote(mapPointsFromRemote: pointDict)
                            //guard !self.isWorking else { break }
                            //self.isWorking = true
                        }
                    }
                case let transformTransmit as TransformTransmit:
                    // only will be sent to slave/follower/replica
                    // update the world transform
                    print("REMOTE Received TransformTransmit \(transformTransmit)")
                    
                    // TODO: update with conversion from transform from transformTransmit to originalTransformToWorld's translation and rotation
                    
                    self.originalTransformToWorld = (float2(), float2x2(), float4x4())
                    self.originalTransformToWorld?.0 = float2(transformTransmit.transform.cmatrix.columns.3.x, transformTransmit.transform.cmatrix.columns.3.y)
                    self.originalTransformToWorld?.1 = float2x2([float2(transformTransmit.transform.cmatrix.columns.0.x, transformTransmit.transform.cmatrix.columns.0.y), float2(transformTransmit.transform.cmatrix.columns.1.x, transformTransmit.transform.cmatrix.columns.1.y)])
                    self.originalTransformToWorld?.2 = transformTransmit.transform
                    
                    print("REMOTE New TransformTransmit informed global position: \(String(describing: self.originalTransformToWorld))")
                    print("REMOTE With TransformTransmit angle \( acos((self.originalTransformToWorld?.1.cmatrix.columns.0.x)!))")
                    self.resolvedWorld = true
                default:
                    print("REMOTE idk what we received")
                }
                default:
                break
            }
            
        }
    }


    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Do nothing
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Do nothing
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        // Do nothing
    }
    
    // MARK: - Gestures

    var viewToCameraFactor: CGFloat {
        return min(metalView.bounds.width, metalView.bounds.height) / 2.0
    }
    
    func convertTranslationFromViewToCamera(_ translation: CGPoint) -> float2 {
        
        let normalizationFactor = viewToCameraFactor
        
        return float2(Float(translation.x / normalizationFactor),
                      Float(translation.y / normalizationFactor))
    }
    
    func convertPointFromViewToCamera(_ point: CGPoint) -> float2 {
        
        let normalizationFactor = viewToCameraFactor
        
        return float2(Float((point.x - metalView.bounds.width / 2.0) / normalizationFactor),
                      Float((point.y - metalView.bounds.height / 2.0) / normalizationFactor))
    }
    
    func convertPointFromScreenToView(_ point: float2) -> CGPoint {
        
        return CGPoint(x: CGFloat(point.x) * metalView.bounds.width / 2.0 + metalView.bounds.width / 2.0,
                       y: CGFloat(point.y) * metalView.bounds.height / 2.0 + metalView.bounds.height / 2.0)
    }
    
    func convertPointFromViewToScreen(_ point: CGPoint) -> float2 {
        
        return float2(Float((point.x - metalView.bounds.width / 2.0) / (metalView.bounds.width / 2.0)),
                      Float((point.y - metalView.bounds.height / 2.0) / (metalView.bounds.height / 2.0)))
    }
    
    @IBAction func translateCamera(_ panGestureRecognizer: NSPanGestureRecognizer) {
        
        guard let renderer = renderer else {
            return
        }
        
        switch panGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            
            let viewTranslation = panGestureRecognizer.translation(in: metalView)
            let cameraTranslation = convertTranslationFromViewToCamera(viewTranslation)
            
            switch renderer.content {
            case .vision:
                renderer.visionCamera.translate(by: cameraTranslation)
            case .map, .vectorMap, .path:
                renderer.mapCamera.translate(by: cameraTranslation)
            case .camera:
                break;
            case .pointcloud:
                
                let translationNormalizer = min(metalView.drawableSize.width, metalView.drawableSize.height) / 2.0
                
                // Translation of finger in y is translation about x axix
                let translation = -.pi * float3(Float(-viewTranslation.y / translationNormalizer), Float(viewTranslation.x / translationNormalizer), 0.0)
                renderer.pointCloudRender.cameraRotation += translation
            }
            
            panGestureRecognizer.setTranslation(CGPoint.zero, in: metalView)
            
            //view.setNeedsUpdateConstraints()
            
        default: break
        }
    }
    
    @IBAction func zoomCamera(_ magnificationGestureRecognizer: NSMagnificationGestureRecognizer) {
        
        guard let renderer = renderer else {
            return
        }
        
        switch magnificationGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            
            let viewLocation = magnificationGestureRecognizer.location(in: metalView)
            let cameraLocation = convertPointFromViewToCamera(viewLocation)
            
            switch renderer.content {
            case .vision:
                renderer.visionCamera.zoom(by: Float(1.0 + magnificationGestureRecognizer.magnification), about: cameraLocation)
            case .map, .vectorMap, .path:
                renderer.mapCamera.zoom(by: Float(1.0 + magnificationGestureRecognizer.magnification), about: cameraLocation)
            case .camera:
                break
            case .pointcloud:
                break
            }
            
            magnificationGestureRecognizer.magnification = 0.0
            
            //view.setNeedsUpdateConstraints()
            
        default: break
        }
    }
    
    @IBAction func rotateCamera(_ rotationGestureRecognizer: NSRotationGestureRecognizer) {
        
        guard let renderer = renderer else {
            return
        }
        
        switch rotationGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            
            let viewLocation = rotationGestureRecognizer.location(in: metalView)
            let cameraLocation = convertPointFromViewToCamera(viewLocation)
            
            switch renderer.content {
            case .vision:
                renderer.visionCamera.rotate(by: Float(rotationGestureRecognizer.rotation), about: cameraLocation)
            case .map, .vectorMap, .path:
                renderer.mapCamera.rotate(by: Float(rotationGestureRecognizer.rotation), about: cameraLocation)
            case .camera:
                break
            case .pointcloud:
                break
            }
            
            rotationGestureRecognizer.rotation = 0.0
            
            //view.setNeedsUpdateConstraints()
            
        default: break
        }
    }
}
