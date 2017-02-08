//
//  ViewController.swift
//  MayApp
//
//  Created by Russell Ladd on 1/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Cocoa
import MultipeerConnectivity

class ViewController: NSViewController, MCNearbyServiceAdvertiserDelegate, SessionManagerDelegate {
    
    let advertiser: MCNearbyServiceAdvertiser
    let sessionManager: SessionManager
    
    let robotController = RobotController()
    let laserController = LaserController()
    
    required init?(coder: NSCoder) {
        
        advertiser = MCNearbyServiceAdvertiser(peer: MCPeerID.shared, discoveryInfo: nil, serviceType: Service.name)
        sessionManager = SessionManager(peer: MCPeerID.shared, serializer: MessageType.self, receiver: robotController)
        
        super.init(coder: coder)
        
        advertiser.delegate = self
        sessionManager.delegate = self
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        
        advertiser.startAdvertisingPeer()
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        
        advertiser.stopAdvertisingPeer()
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        invitationHandler(true, sessionManager.session)
    }
    
    @IBAction func startMotors(_ button: NSButton) {
        
        robotController.receive(RobotCommand(leftMotorVelocity: 20, rightMotorVelocity: 20))
    }
    
    @IBAction func stopMotors(_ button: NSButton) {
        
        robotController.receive(RobotCommand(leftMotorVelocity: 0, rightMotorVelocity: 0))
    }
    
    @IBAction func scan(_ button: NSButton) {
        
        let measurement = LaserMeasurement(distances: laserController.measure(), leftEncoder: self.robotController.encoderLeft, rightEncoder: self.robotController.encoderRight)
        
        sessionManager.send(measurement)
    }
    
    var sendingMeasurements = false {
        didSet {
            
            guard sendingMeasurements != oldValue else { return }
            
            if sendingMeasurements {
                
                laserController.measureContinuously { [unowned self] distances in
                    
                    let measurement = LaserMeasurement(distances: distances, leftEncoder: self.robotController.encoderLeft, rightEncoder: self.robotController.encoderRight)
                    
                    self.sessionManager.send(measurement)
                }
                
            } else {
                
                laserController.stopMeasuring()
            }
        }
    }
    
    func session(_ session: SessionManager, peer: MCPeerID, didChange state: MCSessionState) {
        
        sendingMeasurements = (session.session.connectedPeers.count > 0)
    }
}
