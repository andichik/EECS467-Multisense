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
        
        var depth: UnsafeMutableRawPointer? = nil
        var ts: UInt32 = 0
        
        
        freenect_sync_get_depth(&depth, &ts, 0, FREENECT_DEPTH_REGISTERED)
        print ("one frame")
        
        for i in 0..<(480*640) {
            print (depth!.load(fromByteOffset: 2*i, as: UInt16.self))
        }
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
    
    // MARK: - Laser measurements
    
    var sendingMeasurements = false {
        didSet {
            
            guard sendingMeasurements != oldValue else { return }
            
            if sendingMeasurements {
                
                laserController.measureContinuously { [unowned self] distances in
                    
                    let measurement = LaserMeasurement(distances: distances, leftEncoder: self.arduinoController.encoderLeft, rightEncoder: self.arduinoController.encoderRight)
                    
                    try? self.session.send(MessageType.serialize(measurement), toPeers: self.session.connectedPeers, with: .unreliable)
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
        
        DispatchQueue.main.async(execute: {
            
            switch item {
                
            case let robotCommand as RobotCommand:
                
                self.arduinoController.send(robotCommand)
                
            default: break
            }
        })
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
