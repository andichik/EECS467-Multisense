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
    
    let sessionManager: SessionManager
    
    let receiver: RemoteSessionDataReceiver
    
    // Rendering
    
    let device = MTLCreateSystemDefaultDevice()!
    @IBOutlet var mtkView: MTKView!
    
    let pixelFormat = MTLPixelFormat.rgba16Float
    
    let renderer: Renderer
    
    // Labels
    
    @IBOutlet var leftEncoderLabel: UILabel!
    @IBOutlet var rightEncoderLabel: UILabel!
    @IBOutlet var angleLabel: UILabel!
    
    // Initializer
    
    required init?(coder aDecoder: NSCoder) {
        
        renderer = Renderer(device: device, pixelFormat: pixelFormat)
        
        receiver = RemoteSessionDataReceiver(laserDistanceMesh: renderer.laserDistanceRenderer.laserDistanceMesh)
        sessionManager = SessionManager(peer: MCPeerID.shared, serializer: MessageType.self, receiver: receiver)
        
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mtkView.device = device
        mtkView.colorPixelFormat = pixelFormat
        mtkView.depthStencilPixelFormat = .invalid
        mtkView.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        mtkView.delegate = renderer
        
        receiver.leftEncoderLabel = leftEncoderLabel
        receiver.rightEncoderLabel = rightEncoderLabel
        receiver.angleLabel = angleLabel
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
        browserViewController.maximumNumberOfPeers = 2
        browserViewController.delegate = self
        
        present(browserViewController, animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func motorVelocityChanged(motorVelocityView: PolarInputView) {
        
        //print(motorVelocityView.value)
        
        let value = motorVelocityView.value
        
        let left: Double = 2.0 - (1.0 / M_PI_4) * abs(Double(value.angle) + M_PI_4)
        let right: Double = (1.0 / M_PI_4) * abs(Double(value.angle) - M_PI_4) - 2.0
        
        let clampedLeft: Double = min(max(-1.0, left), 1.0) * Double(value.radius) * 40.0
        let clampedRight: Double = min(max(-1.0, right), 1.0) * Double(value.radius) * 40.0
        
        let robotCommand = RobotCommand(leftMotorVelocity: Int(clampedLeft), rightMotorVelocity: Int(clampedRight))
        
        print(robotCommand)
        
        sessionManager.send(robotCommand)
    }
}
