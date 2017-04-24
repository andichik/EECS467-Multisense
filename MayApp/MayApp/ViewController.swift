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

class MacViewController: NSViewController, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {
    
    // MARK: - Model
    
    let arduinoController = ArduinoController()
    let laserController = LaserController()
    let cameraController = CameraController()

    let mortorController = MotorController()
    
    let odometry = Odometry()
    
    var isAutonomous:Bool = false
    
    var prevPose = Pose()
    
    // MARK: - Rendering
    
    let device = MTLCreateSystemDefaultDevice()
    var metalView: MTKView!
    
    let pixelFormat = MTLPixelFormat.rgba16Float
    
    let renderer: Renderer?
    
    // MARK: - Networking
    
    let session: MCSession
    let advertiser: MCNearbyServiceAdvertiser
    
    // MARK: - Initialization
    
    required init?(coder: NSCoder) {
        
        session = MCSession(peer: MCPeerID.shared)
        advertiser = MCNearbyServiceAdvertiser(peer: MCPeerID.shared, discoveryInfo: nil, serviceType: Service.name)
        
        if let device = device {
            renderer = Renderer(device: device, pixelFormat: pixelFormat, cameraQuality: .medium)
        } else {
            renderer = nil
        }
        
        super.init(coder: coder)
        
        advertiser.delegate = self
        session.delegate = self
    }
    
    // MARK: - View life cycle

    override func viewDidAppear() {
        super.viewDidAppear()
        
        advertiser.startAdvertisingPeer()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
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
                
                if sequenceNumber % 10 == 0 && !self.session.connectedPeers.isEmpty {
                    try self.session.send(MessageType.serialize(sensorMeasurement), toPeers: self.session.connectedPeers, with: .unreliable)
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
            
            renderer.updateVectorMap(odometryDelta: delta, laserDistances: laserDistances, completionHandler: { pose in
                
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
            })
        }
    }
    
    // MARK: - Advertiser delegate
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        invitationHandler(true, session)
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
    
    @IBAction func setPIDStraight(_ sender: Any)
    {
        let kpVal = kpStraight.floatValue
        let kiVal = kiStraight.floatValue
        let kdVal = kdStraight.floatValue
        
        print("straight pid value set to kp: \(kpVal) ki:\(kiVal) kd: \(kdVal) ")
        
        self.mortorController.setMovingController(5.0, kiVal, kdVal)
        
    }
    
    @IBAction func contentChanged(_ sender: NSSegmentedControl) {
        
        renderer?.content = Renderer.Content(rawValue: sender.selectedSegment)!
    }

    // MARK: - Session delegate
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        DispatchQueue.main.async {
            
            if session.connectedPeers.isEmpty {
                self.arduinoController.send(RobotCommand(leftMotorVelocity: 0, rightMotorVelocity: 0))
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        guard let item = MessageType.deserialize(data) else {
            return
        }
        
        DispatchQueue.main.async {
            
            switch item {
                
            case let robotCommand as RobotCommand:
                //print("target x: \(robotCommand.destination.x) target y: \(robotCommand.destination.y) target angle: \(robotCommand.destinationAngle)")
                self.isAutonomous = robotCommand.isAutonomous
                if robotCommand.isAutonomous{
                    //self.mortorController.handlePath(robotCommand.destination, robotCommand.destinationAngle)
            
                    //self.mortorController.addSquare()
//                    self.mortorController.handleMotorCommand(robotCommand: robotCommand)
//                    let velocity = self.mortorController.updateMotorCommand()
//                    print("left velocity: \(velocity.0) right velocity: \(velocity.1)")
//                    self.arduinoController.sendVel(velocity.0, velocity.1)

                    if(robotCommand.destination.x != 0.0 && robotCommand.destination.y != 0.0){
                        print("Receive destination location at x: \(robotCommand.destination.x), y: \(robotCommand.destination.y)")
                        
                        self.renderer?.findPath(destination: robotCommand.destination, algorithm: "A*")
                        self.mortorController.handlePath(newRobotpath: (self.renderer?.pathRenderer.pathBuffer)!)
                    }
                    
                }
                else{
                    self.arduinoController.send(robotCommand)
                }

                
            //should be modified to
            //case let robotPose as Pose:
            //    self.motorController.handlePose(robotPose)
            //    var velocity = self.updateMotorCommand()
            //    self.arduinoController.sned(robotCommand)
            //case let pathPose as Pose:
            //    self.motorController.handlePath(pathPose)

            default: break
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
