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

class ViewController: UIViewController, MCSessionDelegate, MCBrowserViewControllerDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Model
    
    let odometry = Odometry()
    
    // MARK: - Networking
    
    let session: MCSession
    
    // MARK: - Rendering
    
    let device = MTLCreateSystemDefaultDevice()!
    @IBOutlet var metalView: MTKView!
    
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
        
        metalView.device = device
        metalView.colorPixelFormat = pixelFormat
        metalView.depthStencilPixelFormat = .invalid
        metalView.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        metalView.delegate = renderer
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let scale = metalView.traitCollection.displayScale
        
        metalView.drawableSize = metalView.bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
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
    
    var isWorking = false
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        guard let item = MessageType.deserialize(data) else {
            return
        }
        
        DispatchQueue.main.async(execute: {
            
            switch item {
                
            case let laserMeasurement as LaserMeasurement:
                
                guard !self.isWorking else { break }
                self.isWorking = true
                
                let delta = self.odometry.computeDeltaForTicks(left: laserMeasurement.leftEncoder, right: laserMeasurement.rightEncoder)
                
                self.renderer.updateParticlesAndMap(odometryDelta: delta, laserDistances: laserMeasurement.distances, completionHandler: { bestPose in
                    
                    self.updatePoseLabels(with: bestPose)
                    
                    self.renderer.odometryRenderer.updateMeshAndHead(with: bestPose)
                    
                    self.isWorking = false
                })
                
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
    
    func updatePoseLabels(with pose: Pose) {
        
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
    
    // MARK: - Camera gesture recognizers
    
    @IBAction func translateCamera(_ panGestureRecognizer: UIPanGestureRecognizer) {
        
        switch panGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            let translation = panGestureRecognizer.translation(in: metalView)
            renderer.camera.translate(by: float2(Float(translation.x / (metalView.bounds.width / 2.0)), Float(-translation.y / (metalView.bounds.height / 2.0))))
            panGestureRecognizer.setTranslation(CGPoint.zero, in: metalView)
            
        default: break
        }
    }
    
    @IBAction func zoomCamera(_ pinchGestureRecognizer: UIPinchGestureRecognizer) {
        
        switch pinchGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            let location = pinchGestureRecognizer.location(in: metalView)
            renderer.camera.zoom(by: Float(pinchGestureRecognizer.scale), about: float2(Float(location.x / (metalView.bounds.width / 2.0) - 1.0), Float(-location.y / (metalView.bounds.height / 2.0) + 1.0)))
            pinchGestureRecognizer.scale = 1.0
            
        default: break
        }
    }
    
    @IBAction func rotateCamera(_ rotationGestureRecognizer: UIRotationGestureRecognizer) {
        
        switch rotationGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            let location = rotationGestureRecognizer.location(in: metalView)
            renderer.camera.rotate(by: Float(-rotationGestureRecognizer.rotation), about: float2(Float(location.x / (metalView.bounds.width / 2.0) - 1.0), Float(-location.y / (metalView.bounds.height / 2.0) + 1.0)))
            rotationGestureRecognizer.rotation = 0.0
            
        default: break
        }
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        return true
    }
    
    // MARK: - Reset
    
    @IBAction func reset() {
        
        renderer.reset()
    }
}
