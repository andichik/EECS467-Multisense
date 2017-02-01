//
//  ViewController.swift
//  MayApp-iOS
//
//  Created by Russell Ladd on 1/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class ViewController: UIViewController, MCBrowserViewControllerDelegate {
    
    let sessionManager = SessionManager(peer: MCPeerID.shared, serializer: MessageType.self, receiver: RemoteSessionDataReceiver())
    
    @IBAction func browse() {
        
        let browserViewController = MCBrowserViewController(serviceType: Service.name, session: sessionManager.session)
        browserViewController.delegate = self
        
        present(browserViewController, animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func send() {
        
        let robotCommand = RobotCommand(leftMotorVelocity: 20, rightMototVelocity: 15)
        
        sessionManager.send(robotCommand)
    }
}
