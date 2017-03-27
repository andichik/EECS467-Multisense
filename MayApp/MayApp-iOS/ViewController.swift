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

class ViewController: UIViewController, MCSessionDelegate, MCBrowserViewControllerDelegate, MCNearbyServiceBrowserDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Model
    
    let odometry = Odometry()
    
    // MARK: - Networking
    
    let browser = MCNearbyServiceBrowser(peer: MCPeerID.shared, serviceType: Service.name)
    
    let session: MCSession
    
    var savedRobotPeer = SavedPeer(key: "robotPeer")
    
    // MARK: - Rendering
    
    let device = MTLCreateSystemDefaultDevice()!
    @IBOutlet var metalView: MTKView!
    
    let pixelFormat = MTLPixelFormat.rgba16Float
    
    let renderer: Renderer
    
    // MARK: - Views
    
    @IBOutlet var browseButton: UIBarButtonItem!
    @IBOutlet var disconnectButton: UIBarButtonItem!
    
    var connectingIndicator: UIActivityIndicatorView!
    var connectingButton: UIBarButtonItem!
    
    @IBOutlet var poseLabelsVisualEffectView: UIVisualEffectView!
    
    @IBOutlet var poseXLabel: UILabel!
    @IBOutlet var poseYLabel: UILabel!
    @IBOutlet var poseAngleLabel: UILabel!
    
    // MARK: - Initializer
    
    required init?(coder aDecoder: NSCoder) {
        
        session = MCSession(peer: MCPeerID.shared)
        
        renderer = Renderer(device: device, pixelFormat: pixelFormat)
        
        super.init(coder: aDecoder)
        
        session.delegate = self
        
        browser.delegate = self
    }
    
    // MARK: - View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        metalView.device = device
        metalView.colorPixelFormat = pixelFormat
        metalView.depthStencilPixelFormat = .invalid
        metalView.clearColor = MTLClearColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        metalView.delegate = renderer
        
        poseLabelsVisualEffectView.layer.cornerRadius = 10.0
        poseLabelsVisualEffectView.clipsToBounds = true
        
        let monospaceFont = UIFont.monospacedDigitSystemFont(ofSize: 17.0, weight: UIFontWeightRegular)
        
        poseXLabel.font = monospaceFont
        poseYLabel.font = monospaceFont
        poseAngleLabel.font = monospaceFont
        
        connectingIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        connectingButton = UIBarButtonItem(customView: connectingIndicator)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        browser.startBrowsingForPeers()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        browser.stopBrowsingForPeers()
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
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        
        if peerID == savedRobotPeer.peer {
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 0.0)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
    }
    
    @IBAction func disconnect() {
        
        session.disconnect()
    }
    
    // MARK: - Session delegate
    
    var isConnected = false {
        didSet {
            
        }
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        DispatchQueue.main.async {
            
            switch state {
                
            case .notConnected:
                self.connectingIndicator.stopAnimating()
                self.navigationItem.setLeftBarButton(self.browseButton, animated: true)
                
            case .connecting:
                self.connectingIndicator.startAnimating()
                self.navigationItem.setLeftBarButton(self.connectingButton, animated: true)
                
            case .connected:
                self.connectingIndicator.stopAnimating()
                self.navigationItem.setLeftBarButton(self.disconnectButton, animated: true)
                self.dismiss(animated: true, completion: nil)
                self.savedRobotPeer.peer = peerID
            }
        }
    }
    
    var isWorking = false
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        DispatchQueue.main.async {
            
            guard let item = MessageType.deserialize(data) else {
                return
            }
            
            switch item {
                
            case let sensorMeasurement as SensorMeasurement:
                
                guard !self.isWorking else { break }
                self.isWorking = true
                
                print("Received \(sensorMeasurement.sequenceNumber)")
                
                let delta = self.odometry.computeDeltaForTicks(left: sensorMeasurement.leftEncoder, right: sensorMeasurement.rightEncoder)
                
                let laserDistances = sensorMeasurement.laserDistances.withUnsafeBytes { (pointer: UnsafePointer<UInt16>) -> [UInt16] in
                    let buffer = UnsafeBufferPointer(start: pointer, count: sensorMeasurement.laserDistances.count / MemoryLayout<UInt16>.stride)
                    return Array(buffer)
                }
                
                let cameraData = sensorMeasurement.cameraVideo.decompressed(with: .lzfse)!
                let cameraVideo = cameraData.withUnsafeBytes { (pointer: UnsafePointer<Camera.RGBA>) -> [Camera.RGBA] in
                    let buffer = UnsafeBufferPointer(start: pointer, count: cameraData.count / MemoryLayout<Camera.RGBA>.stride)
                    return Array(buffer)
                }
                
                self.renderer.cameraRender.updateCameraTexture(with: cameraVideo)
                
                self.renderer.updateParticlesAndMap(odometryDelta: delta, laserDistances: laserDistances, completionHandler: { bestPose in
                    
                    self.updatePoseLabels(with: bestPose)
                    
                    self.renderer.odometryRenderer.updateMeshAndHead(with: bestPose)
                    
                    self.isWorking = false
                })
                
            default: break
            }
        }
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
    
    let poseLabelFormatter: NumberFormatter = {
        
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    func updatePoseLabels(with pose: Pose) {
        
        poseXLabel.text = poseLabelFormatter.string(from: NSNumber(value: pose.position.x))
        poseYLabel.text = poseLabelFormatter.string(from: NSNumber(value: pose.position.y))
        
        poseAngleLabel.text = poseLabelFormatter.string(from: NSNumber(value: pose.angle))
    }
    
    // MARK: - Polar input view
    
    @IBAction func motorVelocityChanged(motorVelocityView: PolarInputView) {
        
        // NOTE: This function is heavily annotated with types because for some reason it takes forever to compile without the annotations
        
        let value = motorVelocityView.value
        
        let piOver4 = CGFloat(M_PI_4)
        
        let one: CGFloat = 1.0
        let two: CGFloat = 2.0
        let maxVelocity: CGFloat = 50.0
        
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
            renderer.sceneCamera.translate(by: float2(Float(translation.x / (metalView.bounds.width / 2.0)), Float(-translation.y / (metalView.bounds.height / 2.0))))
            panGestureRecognizer.setTranslation(CGPoint.zero, in: metalView)
            
        default: break
        }
    }
    
    @IBAction func zoomCamera(_ pinchGestureRecognizer: UIPinchGestureRecognizer) {
        
        switch pinchGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            let location = pinchGestureRecognizer.location(in: metalView)
            renderer.sceneCamera.zoom(by: Float(pinchGestureRecognizer.scale), about: float2(Float(location.x / (metalView.bounds.width / 2.0) - 1.0), Float(-location.y / (metalView.bounds.height / 2.0) + 1.0)))
            pinchGestureRecognizer.scale = 1.0
            
        default: break
        }
    }
    
    @IBAction func rotateCamera(_ rotationGestureRecognizer: UIRotationGestureRecognizer) {
        
        switch rotationGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            let location = rotationGestureRecognizer.location(in: metalView)
            renderer.sceneCamera.rotate(by: Float(-rotationGestureRecognizer.rotation), about: float2(Float(location.x / (metalView.bounds.width / 2.0) - 1.0), Float(-location.y / (metalView.bounds.height / 2.0) + 1.0)))
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
