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

class ViewController: NSViewController, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    
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
    //@IBOutlet var metalView: MTKView!
    
    let pixelFormat = MTLPixelFormat.rgba16Float
    
    let renderer: Renderer?
    
    // MARK: - Networking
    
    let browser = MCNearbyServiceBrowser(peer: MCPeerID.shared, serviceType: Service.name)
    
    let robotSession: MCSession
    let remoteSession: MCSession
    let advertiser: MCNearbyServiceAdvertiser
    
    var savedRobotPeer = SavedPeer(key: "robotPeer")
    var savedRemotePeer = SavedPeer(key: "otherRobotPeer")
    
    var mapUpdateSequenceNumber = 0
    var pointDictionary = [UUID: MapPoint]()
    
    var resolvedWorld = false
    var originalTransformToWorld: (float2, float2x2, float4x4)?
    var networkingUUID = UUID()
    
    var isConnectedToRobot = false
    var isConnectedToRemote = false
    
    // MARK: - Initialization
    
    required init?(coder: NSCoder) {
        
        robotSession = MCSession(peer: MCPeerID.shared)
        remoteSession = MCSession(peer: MCPeerID.shared)
        
        advertiser = MCNearbyServiceAdvertiser(peer: MCPeerID.shared, discoveryInfo: ["remoteDevice" : "yessir!"], serviceType: Service.name)
        
        if let device = device {
            renderer = Renderer(device: device, pixelFormat: pixelFormat)
        } else {
            renderer = nil
        }
        
        super.init(coder: coder)
        
        advertiser.delegate = self
        robotSession.delegate = self
        remoteSession.delegate = self
        
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
        
        
    }

    // MARK: - Browsing for robot, not remote, peers
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        print("Found Peer: \(peerID.displayName)")
        
        // auto-connection
        if peerID == savedRobotPeer.peer {
            browser.invitePeer(peerID, to: robotSession, withContext: nil, timeout: 0.0)
        }
        
        // otherwise check if remote iOS device using DiscoveryInfo
        if let keys = info {
            if let value = keys["remoteDevice"] {
                if value == "yessir!" {
                    print("Found remote peer")
                    browser.invitePeer(peerID, to: remoteSession, withContext: nil, timeout: 0.0)
                }
            }
        }
        
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
    }
    
    // MARK: - Advertiser delegate
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        invitationHandler(true, robotSession)
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
    // MARK: - Laser measurements
    
    var sendingMeasurements = false {
        didSet {
            
            guard sendingMeasurements != oldValue else { return }
            
            if sendingMeasurements {
                
                var sequenceNumber = 0
                
                laserController.measureContinuously(scanInterval: 0.1) { [unowned self] distances in
                    
                    let cameraMeasurement = self.cameraController.measure()
                    
                    // Create sensor measurement
                    
                    let sensorMeasurement = SensorMeasurement(sequenceNumber: sequenceNumber,
                                                              leftEncoder: self.arduinoController.encoderLeft,
                                                              rightEncoder: self.arduinoController.encoderRight,
                                                              laserDistances: distances,
                                                              cameraVideo: cameraMeasurement.video.compressed(with: .lzfse)!,
                                                              cameraDepth: cameraMeasurement.depth.compressed(with: .lzfse)!)
                    
                    // Send data to remote every tenth frame
                    
                    do {
                        
                        if sequenceNumber % 10 == 0 {
                            try self.robotSession.send(MessageType.serialize(sensorMeasurement), toPeers: self.robotSession.connectedPeers, with: .unreliable)
                        }
                        
                        sequenceNumber += 1
                        print("Sent \(sequenceNumber)")
                        
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
                    
                    let cameraData = sensorMeasurement.cameraVideo.decompressed(with: .lzfse)!
                    let cameraVideo = cameraData.withUnsafeBytes { (pointer: UnsafePointer<Camera.RGBA>) -> [Camera.RGBA] in
                        let buffer = UnsafeBufferPointer(start: pointer, count: cameraData.count / MemoryLayout<Camera.RGBA>.stride)
                        return Array(buffer)
                    }
                    
                    // Get depth data
                    
                    let depthData = sensorMeasurement.cameraDepth.decompressed(with: .lzfse)!
                    let cameraDepth = depthData.withUnsafeBytes { (pointer: UnsafePointer<Camera.Depth>) -> [Camera.Depth] in
                        let buffer = UnsafeBufferPointer(start: pointer, count: depthData.count / MemoryLayout<Camera.Depth>.stride)
                        return Array(buffer)
                    }
                    
                    
                    renderer.cameraRenderer.updateCameraTexture(with: cameraVideo)
                    
                    renderer.pointCloudRender.updatePointcloud(with: cameraDepth)
                    
                    renderer.updateParticlesAndMap(odometryDelta: delta, laserDistances: laserDistances, completionHandler: { bestPose in
                        
                        //self.updatePoseLabels(with: bestPose)
                        
                        renderer.odometryRenderer.updateMeshAndHead(with: bestPose)
                    })
                    
                    renderer.updateVectorMap(odometryDelta: delta, laserDistances: laserDistances, completionHandler: { pose in
                        
                        DispatchQueue.main.async {
                            if self.isAutonomous {
                                //update the current pose from vector map
                                //update motor command
                                //detect a jump in pose
                                let dist = sqrt(pow(pose.0.position.x - self.prevPose.position.x,2) + pow(pose.0.position.y - self.prevPose.position.y,2))
                                if(dist > 1){
                                    print("!!!!!!!JUMP!!!!!!!!!!")
                                }
                                print("current : \(pose.0.position), currentAngle: \(pose.0.angle)")
                                self.mortorController.handlePose(pose.0)
                                self.prevPose = pose.0
                                let velocity = self.mortorController.updateMotorCommand()
                                print("left velocity: \(velocity.0) right velocity: \(velocity.1)")
                                self.arduinoController.sendVel(velocity.0, velocity.1)
                            }
                        }
                    })
                }
                
            } else {
                
                laserController.stopMeasuring()
            }
        }
    }

    // MARK: - Session delegate
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        DispatchQueue.main.async {
            
            switch session {
            case self.robotSession:
                self.sendingMeasurements = !session.connectedPeers.isEmpty
                
                if session.connectedPeers.isEmpty {
                self.arduinoController.send(RobotCommand(leftMotorVelocity: 0, rightMotorVelocity: 0))
                }
            case self.remoteSession:
                switch state {
                case .notConnected:
                    self.isConnectedToRemote = false
                    self.advertiser.startAdvertisingPeer()
                    self.browser.startBrowsingForPeers()
                    print("not connected to other remote")
                    
                case .connecting:
                    print("connecting to other remote")
                    
                case .connected:
                    print("connected to other remote")
                    self.isConnectedToRemote = true
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
            
            switch session {
            case self.robotSession:
                switch item {
                case let robotCommand as RobotCommand:
                //print("target x: \(robotCommand.destination.x) target y: \(robotCommand.destination.y) target angle: \(robotCommand.destinationAngle)")
                self.isAutonomous = robotCommand.isAutonomous
                
                if robotCommand.isAutonomous{
                //self.mortorController.handlePath(robotCommand.destination, robotCommand.destinationAngle)
                    self.mortorController.addSquare()
                //                    self.mortorController.handleMotorCommand(robotCommand: robotCommand)
                //                    let velocity = self.mortorController.updateMotorCommand()
                //                    print("left velocity: \(velocity.0) right velocity: \(velocity.1)")
                //                    self.arduinoController.sendVel(velocity.0, velocity.1)
                }
                else {
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
            case self.remoteSession:
                // packet received from other robot/iDevice
                switch item {
                case let mapUpdate as MapUpdate:
                    print("Received MapUpdate \(mapUpdate.sequenceNumber)") //\(mapUpdate)")
                    
                    // resolve world transform
                    if !self.resolvedWorld {
                        
                        // master/leader/primary
                        print("\(self.networkingUUID), \(mapUpdate.robotId)")
                        if true {
                            //if UUID.greater(lhs: self.networkingUUID, rhs: mapUpdate.robotId) {
                            // TODO: SWAP COMMENTED IF STATEMENT LINES ABOVE
                            print("I am the master")
                            //if networkingUUID > mapUpdate.robotId {
                            
                            let replicaTransform = self.renderer?.resolveWorld(pointDictionaryRemote: mapUpdate.pointDictionary)
                            self.resolvedWorld = (replicaTransform != nil)
                            
                            print("World resolved? \(self.resolvedWorld)")
                            
                            // transmit to slave/follower/replica if solved
                            if let transform = replicaTransform {
                                self.originalTransformToWorld?.0 = float2(x: 0.0, y: 0.0)
                                self.originalTransformToWorld?.1 = float2x2(diagonal: float2(1.0))
                                self.originalTransformToWorld?.2 = float4x4(diagonal: float4(1.0, 1.0, 1.0, 1.0))
                                
                                let transformTransmit = TransformTransmit(transform: transform)
                                
                                if !transform.cmatrix.columns.0.x.isNaN  {
                                    
                                    print("sent transformTransmit: \(transformTransmit)")
                                    
                                    try? self.remoteSession.send(MessageType.serialize(transformTransmit), toPeers: self.remoteSession.connectedPeers, with: .unreliable)
                                    
                                }
                                else {
                                    print("not sending transforms: \(transformTransmit)")
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
                            
                            self.renderer?.updateVectorMapFromRemote(mapPointsFromRemote: pointDict)
                            //guard !self.isWorking else { break }
                            //self.isWorking = true
                        }
                    }
                default: break
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
}
