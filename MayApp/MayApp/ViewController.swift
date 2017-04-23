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

class ViewController: NSViewController, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {
    
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
    
    let session: MCSession
    let advertiser: MCNearbyServiceAdvertiser
    
    // MARK: - Initialization
    
    required init?(coder: NSCoder) {
        
        session = MCSession(peer: MCPeerID.shared)
        advertiser = MCNearbyServiceAdvertiser(peer: MCPeerID.shared, discoveryInfo: nil, serviceType: Service.name)
        
        if let device = device {
            renderer = Renderer(device: device, pixelFormat: pixelFormat)
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
                            try self.session.send(MessageType.serialize(sensorMeasurement), toPeers: self.session.connectedPeers, with: .unreliable)
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
                
            } else {
                
                laserController.stopMeasuring()
            }
        }
    }
    
    // MARK: - Session delegate
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        DispatchQueue.main.async {
            
            self.sendingMeasurements = !session.connectedPeers.isEmpty
            
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
                    self.mortorController.addSquare()
//                    self.mortorController.handleMotorCommand(robotCommand: robotCommand)
//                    let velocity = self.mortorController.updateMotorCommand()
//                    print("left velocity: \(velocity.0) right velocity: \(velocity.1)")
//                    self.arduinoController.sendVel(velocity.0, velocity.1)
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
}
