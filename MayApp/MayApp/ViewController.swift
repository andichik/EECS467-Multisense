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
    let sessionDataReceiver: RobotSessionDataReceiver
    
    required init?(coder: NSCoder) {
        
        sessionDataReceiver = RobotSessionDataReceiver()
        
        advertiser = MCNearbyServiceAdvertiser(peer: MCPeerID.shared, discoveryInfo: nil, serviceType: Service.name)
        sessionManager = SessionManager(peer: MCPeerID.shared, typer: MessageType.self, receiver: sessionDataReceiver)
        
        super.init(coder: coder)
        
        advertiser.delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
}
