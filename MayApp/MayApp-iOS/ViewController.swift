//
//  ViewController.swift
//  MayApp-iOS
//
//  Created by Russell Ladd on 1/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import Metal
import MetalKit

class ViewController: UIViewController, MCBrowserViewControllerDelegate {
    
    // Networking
    
    let sessionManager = SessionManager(peer: MCPeerID.shared, serializer: MessageType.self, receiver: RemoteSessionDataReceiver())
    
    // Rendering
    
    let device = MTLCreateSystemDefaultDevice()!
    @IBOutlet var mtkView: MTKView!
    
    let pixelFormat = MTLPixelFormat.rgba16Float
    
    let renderer: Renderer
    
    required init?(coder aDecoder: NSCoder) {
        
        renderer = Renderer(device: device, pixelFormat: pixelFormat)
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView.device = device
        mtkView.colorPixelFormat = pixelFormat
        mtkView.depthStencilPixelFormat = .invalid
        mtkView.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        mtkView.delegate = renderer
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let scale = mtkView.traitCollection.displayScale
        
        mtkView.drawableSize = mtkView.bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        mtkView.isPaused = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        mtkView.isPaused = true
    }
    
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
