//
//  ViewController.swift
//  MayApp
//
//  Created by Russell Ladd on 1/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Cocoa
import MultipeerConnectivity

class ViewController: NSViewController, MCNearbyServiceAdvertiserDelegate {
    
    let advertiser: MCNearbyServiceAdvertiser
    let sessionManager: SessionManager
    let controller: RobotController
    
    required init?(coder: NSCoder) {
        
        controller = RobotController()
        
        advertiser = MCNearbyServiceAdvertiser(peer: MCPeerID.shared, discoveryInfo: nil, serviceType: Service.name)
        sessionManager = SessionManager(peer: MCPeerID.shared, serializer: MessageType.self, receiver: controller)
        
        super.init(coder: coder)
        
        advertiser.delegate = self
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
        
        controller.receive(RobotCommand(leftMotorVelocity: 20, rightMotorVelocity: 20))
    }
    
    @IBAction func stopMotors(_ button: NSButton) {
        
        controller.receive(RobotCommand(leftMotorVelocity: 0, rightMotorVelocity: 0))
    }
}
