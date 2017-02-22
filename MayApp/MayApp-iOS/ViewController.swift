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
import MayAppCommon

class ViewController: UIViewController, MCSessionDelegate, MCBrowserViewControllerDelegate {
    
    // MARK: - Model
    
    let odometry = Odometry()
    
    var pose = Pose()
    
    // MARK: - Networking
    
    let session: MCSession
    
    // MARK: - Rendering
    
    let device = MTLCreateSystemDefaultDevice()!
    @IBOutlet var mtkView: MTKView!
    
    let pixelFormat = MTLPixelFormat.rgba16Float
    
    let renderer: Renderer
    
    // MARK: - Views
    
    @IBOutlet var leftEncoderLabel: UILabel!
    @IBOutlet var rightEncoderLabel: UILabel!
    @IBOutlet var angleLabel: UILabel!
    
    // MARK: - Initializer
    
    required init?(coder aDecoder: NSCoder) {
        
        session = MCSession(peer: MCPeerID.shared)
        
        renderer = Renderer(device: device, pixelFormat: pixelFormat)
        
        super.init(coder: aDecoder)
        
        session.delegate = self
    }
    
    // MARK: - View life cycle
    
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
    
    // MARK: - Browsing for peers
    
    @IBAction func browse() {
        
        let browserViewController = MCBrowserViewController(serviceType: Service.name, session: session)
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
    
    // MARK: - Session delegate
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // Do nothing
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        guard let item = MessageType.deserialize(data) else {
            return
        }
        
        DispatchQueue.main.async(execute: {
            
            switch item {
                
            case let laserMeasurement as LaserMeasurement:
                
                guard !self.renderer.isWorking else { break }
                
                self.renderer.laserDistanceRenderer.updateMesh(with: laserMeasurement.distances)
                
                let delta = self.odometry.computeDeltaForTicks(left: laserMeasurement.leftEncoder, right: laserMeasurement.rightEncoder)
                self.pose.apply(delta: delta)
                
                self.updatePoseLabels()
                
                self.renderer.odometryRenderer.updateMeshAndHead(with: self.pose)
                
                self.renderer.mapRenderer.currentPose = self.pose
                self.renderer.mapRenderer.updateLaserDistancesTexture(with: laserMeasurement.distances)
                
                self.renderer.particleRenderer.updateOdometry(with: delta)
                
                self.mtkView.draw()
                
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
    
    // MARK: - Labels
    
    func updatePoseLabels() {
        
        leftEncoderLabel.text = String(pose.position.x)
        rightEncoderLabel.text = String(pose.position.y)
        
        angleLabel.text = String(pose.angle)
    }
    
    // MARK: - Polar input view
    
    @IBAction func motorVelocityChanged(motorVelocityView: PolarInputView) {
        
        // NOTE: This function is heavily annotated with types because for some reason it takes forever to compile without the annotations
        
        let value = motorVelocityView.value
        
        let piOver4 = CGFloat(M_PI_4)
        
        let one: CGFloat = 1.0
        let two: CGFloat = 2.0
        let maxVelocity: CGFloat = 40.0
        
        let leftAbs: CGFloat = abs(value.angle + piOver4)
        let rightAbs: CGFloat = abs(value.angle - piOver4)
        
        let left:  CGFloat = two - (one / piOver4) * leftAbs
        let right: CGFloat =       (one / piOver4) * rightAbs - two
        
        let clampedLeft:  CGFloat = min(max(-one, left ), 1.0) * value.radius * maxVelocity
        let clampedRight: CGFloat = min(max(-one, right), 1.0) * value.radius * maxVelocity
        
        let robotCommand = RobotCommand(leftMotorVelocity: Int(clampedLeft),
                                        rightMotorVelocity: Int(clampedRight))
        
        try? session.send(MessageType.serialize(robotCommand), toPeers: session.connectedPeers, with: .unreliable)
    }
    
    // MARK: - Renderer content mode
    
    @IBAction func renderContentSelectorChanged(_ segmentedControl: UISegmentedControl) {
        
        renderer.content = Renderer.Content(rawValue: segmentedControl.selectedSegmentIndex)!
    }
    
    // MARK: - Reset
    
    @IBAction func reset() {
        
        renderer.reset()
    }
}
