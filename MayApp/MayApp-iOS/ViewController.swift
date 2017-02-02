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
    
    @IBAction func startMotorsForward() {
        
        let robotCommand = RobotCommand(leftMotorVelocity: 20, rightMotorVelocity: 20)
        
        sessionManager.send(robotCommand)
    }
    
    @IBAction func startMotorsBackward() {
        
        let robotCommand = RobotCommand(leftMotorVelocity: -20, rightMotorVelocity: -20)
        
        sessionManager.send(robotCommand)
    }
    
    @IBAction func startMotorsLeft() {
        
        let robotCommand = RobotCommand(leftMotorVelocity: 10, rightMotorVelocity: 20)
        
        sessionManager.send(robotCommand)
    }
    
    @IBAction func startMotorsRight() {
        
        let robotCommand = RobotCommand(leftMotorVelocity: 10, rightMotorVelocity: 20)
        
        sessionManager.send(robotCommand)
    }
    
    @IBAction func stopMotors() {
        
        let robotCommand = RobotCommand(leftMotorVelocity: 0, rightMotorVelocity: 0)
        
        sessionManager.send(robotCommand)
    }
}
