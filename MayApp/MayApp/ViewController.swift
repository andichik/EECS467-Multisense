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

class ViewController: NSViewController, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {
    
    // MARK: - Model
    
    let arduinoController = ArduinoController()
    let laserController = LaserController()
    let cameraController = CameraController()
    let pidController = PIDController()
    
    let compressionController = CompressionController(timeInterval: 0.1)
    
    // MARK: - Networking
    
    let session: MCSession
    let advertiser: MCNearbyServiceAdvertiser
    
    // MARK: - Initialization
    
    required init?(coder: NSCoder) {
        
        session = MCSession(peer: MCPeerID.shared)
        advertiser = MCNearbyServiceAdvertiser(peer: MCPeerID.shared, discoveryInfo: nil, serviceType: Service.name)
        
        super.init(coder: coder)
        
        advertiser.delegate = self
        session.delegate = self
    }
    
    // MARK: - View life cycle

    override func viewDidAppear() {
        super.viewDidAppear()
        
        advertiser.startAdvertisingPeer()
        
        sendingMeasurements = true
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        advertiser.stopAdvertisingPeer()
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
    
    @IBAction func setPID(_ sender: Any) {
        let kpVal = Kp.floatValue
        let kiVal = Ki.floatValue
        let kdVal = Kd.floatValue
        
        print("pid value set to kp: \(kpVal) ki:\(kiVal) kd: \(kdVal) ")
        pidController.resetPIDVal(K_p: kpVal, K_i: kiVal, K_d: kdVal)
    }
    
    
    // MARK: - Laser measurements
    
    var sendingMeasurements = false {
        didSet {
            
            guard sendingMeasurements != oldValue else { return }
            
            if sendingMeasurements {
                
                var sequenceNumber = 0
                
                laserController.measureContinuously { [unowned self] distances in
                    
                    let cameraMeasurement = self.cameraController.measure()
                    
                    self.compressionController.compress(cameraMeasurement.video) { compressedVideo in
                        
                        let measurement = SensorMeasurement(sequenceNumber: sequenceNumber,
                                                            leftEncoder: self.arduinoController.encoderLeft,
                                                            rightEncoder: self.arduinoController.encoderRight,
                                                            laserDistances: distances,
                                                            cameraVideo: compressedVideo,
                                                            cameraDepth: cameraMeasurement.depth.compressed(with: .lzfse)!)
                        
                        do {
                            
                            let data = MessageType.serialize(measurement)
                            
                            print(data.count)
                            
                            try self.session.send(data, toPeers: self.session.connectedPeers, with: .unreliable)
                            
                            sequenceNumber += 1
                            print("Sent \(sequenceNumber)")
                            
                        } catch {
                            
                            print("Error \(error)")
                        }
                    }
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
                
                self.arduinoController.driveRobot(robotCommand)

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
