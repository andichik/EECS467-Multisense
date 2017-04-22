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

class ViewController: UIViewController, MCSessionDelegate, MCBrowserViewControllerDelegate, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, UIGestureRecognizerDelegate {
    
    // MARK: - Model
    
    let odometry = Odometry()
    
    // MARK: - Networking
    
    let browser = MCNearbyServiceBrowser(peer: MCPeerID.shared, serviceType: Service.name)
    
    let robotSession: MCSession
    let remoteSession: MCSession
    let advertiser: MCNearbyServiceAdvertiser
    
    var savedRobotPeer = SavedPeer(key: "robotPeer")
    var savedRemotePeer = SavedPeer(key: "otherRobotPeer")
    
    var mapUpdateSequenceNumber = 0
    var pointDictionary = [UUID: MapPoint]()
    
    var resolvedWorld = false
    var originalTransformToWorld: (float2, float2x2)?//: (float2(1.0), float2x2(diagonal: float2(1.0)))
    var networkingUUID = UUID()
    
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
        
        robotSession = MCSession(peer: MCPeerID.shared)
        remoteSession = MCSession(peer: MCPeerID.shared)
        
        advertiser = MCNearbyServiceAdvertiser(peer: MCPeerID.shared, discoveryInfo: ["remoteDevice" : "yessir!"], serviceType: Service.name)
        
        renderer = Renderer(device: device, pixelFormat: pixelFormat)
        
        super.init(coder: aDecoder)
        
        advertiser.delegate = self
        robotSession.delegate = self
        remoteSession.delegate = self
        
        browser.delegate = self
        
    }
    
    // MARK: - View life cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        metalView.device = device
        metalView.colorPixelFormat = pixelFormat
        metalView.depthStencilPixelFormat = .depth32Float
        metalView.clearDepth = 10.0
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
        
        // send robot commands
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            
            let currentPosition = self.renderer.poseRenderer.pose.position.xy
            
            if distance(currentPosition, self.destination) < 0.5 {
                self.isAutonomous = false
            }
            
            if self.isConnectedToRobot {
                let robotCommand = RobotCommand(leftMotorVelocity: self.leftMotorVelocity,
                                                rightMotorVelocity: self.rightMotorVelocity,
                                                currentPosition: currentPosition,
                                                destination: self.destination,
                                                isAutonomous: self.isAutonomous)
                
                //print("sent robotCommand: destination: \(self.destination)")
                
                try? self.robotSession.send(MessageType.serialize(robotCommand), toPeers: self.robotSession.connectedPeers, with: .unreliable)
            }
        }
        
        // send map updates
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            
            if self.isConnectedToRemote {
                
                let currentPosition = self.renderer.poseRenderer.pose.position.xy
                let currentRotation = float2x2(self.renderer.poseRenderer.pose.angle)
                
                var globalPosition: float2
                var globalRotation: float2x2
                
                if let globeTransform = self.originalTransformToWorld {
                    globalPosition = currentPosition - globeTransform.0
                    globalRotation = currentRotation - globeTransform.1
                }
                else {
                    globalPosition = float2(x: 0.0, y: 0.0)
                    globalRotation = float2x2(angle: 0.0)
                }
                
                let transform = float4x4(translation: globalPosition) * float4x4(rotation: globalRotation)
                
                // calculate global transform and apply to pointDictionary
                var pointDict = [UUID: MapPoint]()
                for (key, value) in self.pointDictionary {
                    pointDict[key] = value.applying(transform: transform)
                }
                
                if pointDict.count != 0 {
                    self.mapUpdateSequenceNumber += 1
                    let mapUpdate = MapUpdate(sequenceNumber: self.mapUpdateSequenceNumber, pointDictionary: pointDict, robotId: self.networkingUUID)
                    
                    // TODO: CONVERT TO WORLD COORDINATES THROUGH ORIGINAL TRANSFORM AND POSITION
                    
                    // print("sent mapUpdate: \(mapUpdate.sequenceNumber), \(mapUpdate.pointDictionary.count)")
                    
                    
                    try? self.remoteSession.send(MessageType.serialize(mapUpdate), toPeers: self.remoteSession.connectedPeers, with: .unreliable)
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        browser.startBrowsingForPeers()
        
        advertiser.startAdvertisingPeer()

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        browser.stopBrowsingForPeers()
        
        advertiser.stopAdvertisingPeer()

    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let scale = metalView.traitCollection.displayScale
        
        metalView.drawableSize = metalView.bounds.size.applying(CGAffineTransform(scaleX: scale, y: scale))
    }
    
    override func updateViewConstraints() {
        super.updateViewConstraints()
        
        updateRoomSignPositions()
    }
    
    // MARK: - Browsing for robot, not remote, peers
    
    @IBAction func browse() {
        
        let browserViewController = MCBrowserViewController(serviceType: Service.name, session: robotSession)
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
        
        print("Found Peer: \(peerID.displayName)")
        
        // auto-connection
        if peerID == savedRobotPeer.peer {
            browser.invitePeer(peerID, to: robotSession, withContext: nil, timeout: 0.0)
        }
        
        // otherwise check if remote iOS device using DiscoveryInfo
        if let keys = info {
            if let value = keys["remoteDevice"] {
                if value == "yessir!" {
                    print("Found remote peer")
                    browser.invitePeer(peerID, to: remoteSession, withContext: nil, timeout: 0.0)
                }
            }
        }
        
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        
    }
    
    @IBAction func disconnect() {
        
        robotSession.disconnect()
    }
    
    // MARK: - Advertiser delegate
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        invitationHandler(true, remoteSession)
    }
    
    // MARK: - Session delegate
    
    var isConnectedToRobot = false {
        didSet {
            // Apparently unused?
            // FIXME: Remove this if no one is using it.
        }
    }
    
    var isConnectedToRemote = false {
        didSet {
            
        }
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        DispatchQueue.main.async {
            
            switch session {
            case self.robotSession:
                switch state {
                    case .notConnected:
                        self.connectingIndicator.stopAnimating()
                        self.navigationItem.setLeftBarButton(self.browseButton, animated: true)
                        self.isConnectedToRobot = false
                        
                    case .connecting:
                        self.connectingIndicator.startAnimating()
                        self.navigationItem.setLeftBarButton(self.connectingButton, animated: true)
                        
                    case .connected:
                        self.connectingIndicator.stopAnimating()
                        self.navigationItem.setLeftBarButton(self.disconnectButton, animated: true)
                        self.dismiss(animated: true, completion: nil)
                        self.savedRobotPeer.peer = peerID
                        self.isConnectedToRobot = true
                }
            case self.remoteSession:
                switch state {
                case .notConnected:
                    self.isConnectedToRemote = false
                    self.advertiser.startAdvertisingPeer()
                    self.browser.startBrowsingForPeers()
                    print("not connected to other remote")
                    
                case .connecting:
                    print("connecting to other remote")
                    
                case .connected:
                    print("connected to other remote")
                    self.isConnectedToRemote = true
                    self.savedRemotePeer.peer = peerID
                }

            default:
                break
            }
        }
    }
    
    var isWorking = false
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        DispatchQueue.main.async {
            
            //print("Received something")
            
            guard let item = MessageType.deserialize(data) else {
                print("Received nothing apparently")
                print(String(bytes: data, encoding: String.Encoding.utf8)!)
                return
            }
            
            switch session {
            case self.remoteSession:
                // packet received from other robot/iDevice
                switch item {
                case let mapUpdate as MapUpdate:
                    print("Received MapUpdate \(mapUpdate.sequenceNumber)") //\(mapUpdate)")
                    
                    // resolve world transform
                    if !self.resolvedWorld {
                        
                        // master/leader/primary
                        print("\(self.networkingUUID), \(mapUpdate.robotId)")
                        if UUID.greater(lhs: self.networkingUUID, rhs: mapUpdate.robotId) {
                            print("I am the master")
                        //if networkingUUID > mapUpdate.robotId {

                            let replicaTransform = self.renderer.resolveWorld(pointDictionaryRemote: mapUpdate.pointDictionary)
                            self.resolvedWorld = (replicaTransform != nil)
                            
                            print("World resolved? \(self.resolvedWorld)")
                            
                            // transmit to slave/follower/replica if solved
                            if let transforms = replicaTransform {
                                self.originalTransformToWorld?.0 = float2(x: 0.0, y: 0.0)
                                self.originalTransformToWorld?.1 = float2x2(diagonal: float2(1.0))
                                
                                let transformTransmit = TransformTransmit(translation: transforms.0, rotation: transforms.1)
                                
                                if transforms.0.x != Float.nan {
                                    
                                    print("sent transformTransmit: \(transformTransmit)")
                                    
                                    try? self.remoteSession.send(MessageType.serialize(transformTransmit), toPeers: self.remoteSession.connectedPeers, with: .unreliable)
                                    
                                }
                                else {
                                    print("not sending transforms: \(transformTransmit)")
                                    self.resolvedWorld = false
                                }
                            }
                        }
                        // do nothing as a slave/follower/replica, other then wait for transmission of your transform to global from master/leader/primary
                    }
                    else {
                        // TODO: apply globe-to-local transform and add to local map
                        let currentPosition = self.renderer.poseRenderer.pose.position.xy
                        let currentRotation = float2x2(self.renderer.poseRenderer.pose.angle)
                        
                        var globalPosition: float2
                        var globalRotation: float2x2

                        if let globeTransform = self.originalTransformToWorld {
                            globalPosition = globeTransform.0 - currentPosition
                            globalRotation = globeTransform.1 - currentRotation
                        }
                        else {
                            globalPosition = float2(x: 0.0, y: 0.0)
                            globalRotation = float2x2(angle: 0.0)
                        }
                        
                        let transform = float4x4(translation: globalPosition) * float4x4(rotation: globalRotation)
                        
                        // calculate global transform and apply to imported pointDict
                        var pointDict = [UUID: MapPoint]()
                        for (key, value) in mapUpdate.pointDictionary {
                            pointDict[key] = value.applying(transform: transform)
                        }
                        
                        self.renderer.updateVectorMapFromRemote(mapPointsFromRemote: pointDict)
                        
                        //guard !self.isWorking else { break }
                        //self.isWorking = true
                    }
                
                case let transformTransmit as TransformTransmit:
                    // only will be sent to slave/follower/replica
                    // update the world transform
                    self.resolvedWorld = true
                    self.originalTransformToWorld = (transformTransmit.translation, transformTransmit.rotation)
                    print("Received TransformTransmit \(transformTransmit)")
                    
                default:
                    print("idk what we got in remote session")
                    print(String(bytes: data, encoding: String.Encoding.utf8)!)
                }
                
            case self.robotSession:
                // ok, must be robot session
                switch item {
                    
                // packet received from companion robot
                case let sensorMeasurement as SensorMeasurement:
                    
                    guard !self.isWorking else { break }
                    self.isWorking = true
                    
                    //print("Received sensorMeasurement \(sensorMeasurement.sequenceNumber)")
                    
                    // Compute delta
                    
                    let delta = self.odometry.computeDeltaForTicks(left: sensorMeasurement.leftEncoder, right: sensorMeasurement.rightEncoder)
                    
                    // Get laser distances
                    
                    let laserDistances = sensorMeasurement.laserDistances.withUnsafeBytes { (pointer: UnsafePointer<UInt16>) -> [UInt16] in
                        let buffer = UnsafeBufferPointer(start: pointer, count: sensorMeasurement.laserDistances.count / MemoryLayout<UInt16>.stride)
                        return Array(buffer)
                    }
                    
                    // Get camera data
                    
                    let cameraData = sensorMeasurement.cameraVideo.decompressed(with: .lzfse)!
                    let cameraVideo = cameraData.withUnsafeBytes { (pointer: UnsafePointer<Camera.RGBA>) -> [Camera.RGBA] in
                        let buffer = UnsafeBufferPointer(start: pointer, count: cameraData.count / MemoryLayout<Camera.RGBA>.stride)
                        return Array(buffer)
                    }
                    
                    // Get depth data
                    
                    let depthData = sensorMeasurement.cameraDepth.decompressed(with: .lzfse)!
                    let cameraDepth = depthData.withUnsafeBytes { (pointer: UnsafePointer<Camera.Depth>) -> [Camera.Depth] in
                        let buffer = UnsafeBufferPointer(start: pointer, count: depthData.count / MemoryLayout<Camera.Depth>.stride)
                        return Array(buffer)
                    }
                    
                    
                    self.renderer.cameraRenderer.updateCameraTexture(with: cameraVideo)
                    
                    self.renderer.pointCloudRender.updatePointcloud(with: cameraDepth)
                    
                    self.renderer.updateParticlesAndMap(odometryDelta: delta, laserDistances: laserDistances, completionHandler: { bestPose in
                        
                        self.updatePoseLabels(with: bestPose)
                        
                        self.renderer.odometryRenderer.updateMeshAndHead(with: bestPose)
                        
                        self.isWorking = false
                    })
                    
                    self.renderer.updateVectorMap(odometryDelta: delta, laserDistances: laserDistances, completionHandler: { pose, mapPoints in
                        
                        DispatchQueue.main.async {
                            
                            let newRoomNames = self.renderer.cameraRenderer.tagDetectionAndPoseEsimtation(with: cameraDepth, from: pose)
                            
                            for roomName in newRoomNames {
                                self.addRoomSign(name: roomName)
                            }
                            
                            self.pointDictionary = mapPoints
                        }
                    })
                    
                default:
                    print("In robot session, received something unrecognized")
                    break
                }
            default:
                break
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
    
    var leftMotorVelocity = 0
    var rightMotorVelocity = 0
    
    @IBAction func motorVelocityChanged(motorVelocityView: PolarInputView) {
        
        // NOTE: This function is heavily annotated with types because for some reason it takes forever to compile without the annotations
        
        let value = motorVelocityView.value
        
        let piOver4 = CGFloat.pi / 4.0
        
        let one: CGFloat = 1.0
        let two: CGFloat = 2.0
        let maxVelocity: CGFloat = 50.0
        
        let leftAbs: CGFloat = abs(value.angle + piOver4)
        let rightAbs: CGFloat = abs(value.angle - piOver4)
        
        let left:  CGFloat = two - (one / piOver4) * leftAbs
        let right: CGFloat =       (one / piOver4) * rightAbs - two
        
        let clampedLeft:  CGFloat = min(max(-one, left ), 1.0) * value.radius * maxVelocity
        let clampedRight: CGFloat = min(max(-one, right), 1.0) * value.radius * maxVelocity
        
        leftMotorVelocity = Int(clampedLeft)
        rightMotorVelocity = Int(clampedRight)
        isAutonomous = false;
    }
    
    // MARK: - Renderer content mode
    
    @IBAction func renderContentSelectorChanged(_ segmentedControl: UISegmentedControl) {
        
        renderer.content = Renderer.Content(rawValue: segmentedControl.selectedSegmentIndex)!
    }
    
    // MARK: - Room signs
    
    var roomSigns: [RoomSignContainer] = []
    
    final class RoomSignContainer {
        
        init(name: String, position: float4, in view: UIView) {
            
            self.view = RoomSignView()
            self.view.translatesAutoresizingMaskIntoConstraints = false
            self.view.label.text = name
            
            self.position = position
            
            self.xConstraint = self.view.centerXAnchor.constraint(equalTo: view.leftAnchor)
            self.yConstraint = self.view.centerYAnchor.constraint(equalTo: view.topAnchor)
            
            view.addSubview(self.view)
            
            NSLayoutConstraint.activate([self.xConstraint, self.yConstraint])
        }
        
        let view: RoomSignView
        
        let position: float4
        
        let xConstraint: NSLayoutConstraint
        let yConstraint: NSLayoutConstraint
    }
    
    func addRoomSign(name: String) {
        
        let position = renderer.cameraRenderer.doorsignCollection[name]!
        
        roomSigns.append(RoomSignContainer(name: name, position: position, in: metalView))
        
        updateRoomSignPositions()
    }
    
    func updateRoomSignPositions() {
        
        for roomSign in roomSigns {
            
            let center = convertPointFromScreenToView(renderer.project(roomSign.position).xy)
            
            roomSign.xConstraint.constant = center.x
            roomSign.yConstraint.constant = center.y
        }
    }
    
    // MARK: - Camera gesture recognizers
    
    var viewToCameraFactor: CGFloat {
        return min(metalView.bounds.width, metalView.bounds.height) / 2.0
    }
    
    func convertTranslationFromViewToCamera(_ translation: CGPoint) -> float2 {
        
        let normalizationFactor = viewToCameraFactor
        
        return float2(Float(translation.x / normalizationFactor),
                      Float(-translation.y / normalizationFactor))
    }
    
    func convertPointFromViewToCamera(_ point: CGPoint) -> float2 {
        
        let normalizationFactor = viewToCameraFactor
        
        return float2(Float((point.x - metalView.bounds.width / 2.0) / normalizationFactor),
                      Float((metalView.bounds.height / 2.0 - point.y) / normalizationFactor))
    }
    
    func convertPointFromScreenToView(_ point: float2) -> CGPoint {
        
        return CGPoint(x: CGFloat(point.x) * metalView.bounds.width / 2.0 + metalView.bounds.width / 2.0,
                       y: metalView.bounds.height / 2.0 - CGFloat(point.y) * metalView.bounds.height / 2.0)
    }
    
    func convertPointFromViewToScreen(_ point: CGPoint) -> float2 {
        
        return float2(Float((point.x - metalView.bounds.width / 2.0) / (metalView.bounds.width / 2.0)),
                      Float((metalView.bounds.height / 2.0 - point.y) / (metalView.bounds.height / 2.0)))
    }
    
    @IBAction func translateCamera(_ panGestureRecognizer: UIPanGestureRecognizer) {
        
        switch panGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            
            let viewTranslation = panGestureRecognizer.translation(in: metalView)
            let cameraTranslation = convertTranslationFromViewToCamera(viewTranslation)
            
            switch renderer.content {
            case .vision:
                renderer.visionCamera.translate(by: cameraTranslation)
            case .map, .vectorMap, .path:
                renderer.mapCamera.translate(by: cameraTranslation)
            case .camera:
                break;
            case .pointcloud:

                let translationNormalizer = min(metalView.drawableSize.width, metalView.drawableSize.height) / 2.0
                
                // Translation of finger in y is translation about x axix
                let translation = -.pi * float3(Float(viewTranslation.y / translationNormalizer), Float(viewTranslation.x / translationNormalizer), 0.0)
                renderer.pointCloudRender.cameraRotation += translation
                
            }
            
            panGestureRecognizer.setTranslation(CGPoint.zero, in: metalView)
            
            view.setNeedsUpdateConstraints()
            
        default: break
        }
    }
    
    @IBAction func zoomCamera(_ pinchGestureRecognizer: UIPinchGestureRecognizer) {
        
        switch pinchGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            
            let viewLocation = pinchGestureRecognizer.location(in: metalView)
            let cameraLocation = convertPointFromViewToCamera(viewLocation)
            
            switch renderer.content {
            case .vision:
                renderer.visionCamera.zoom(by: Float(pinchGestureRecognizer.scale), about: cameraLocation)
            case .map, .vectorMap, .path:
                renderer.mapCamera.zoom(by: Float(pinchGestureRecognizer.scale), about: cameraLocation)
            case .camera:
                break
            case .pointcloud:
                break
            }
            
            pinchGestureRecognizer.scale = 1.0
            
            view.setNeedsUpdateConstraints()
            
        default: break
        }
    }
    
    @IBAction func rotateCamera(_ rotationGestureRecognizer: UIRotationGestureRecognizer) {
        
        switch rotationGestureRecognizer.state {
            
        case .began, .changed, .ended, .cancelled:
            
            let viewLocation = rotationGestureRecognizer.location(in: metalView)
            let cameraLocation = convertPointFromViewToCamera(viewLocation)
            
            switch renderer.content {
            case .vision:
                renderer.visionCamera.rotate(by: Float(-rotationGestureRecognizer.rotation), about: cameraLocation)
            case .map, .vectorMap, .path:
                renderer.mapCamera.rotate(by: Float(-rotationGestureRecognizer.rotation), about: cameraLocation)
            case .camera:
                break
            case .pointcloud:
                break
            }
            
            rotationGestureRecognizer.rotation = 0.0
            
            view.setNeedsUpdateConstraints()
            
        default: break
        }
    }
    

    @IBAction func updateDestination(_ tapGestureRecognizer: UITapGestureRecognizer) {
        
        if tapGestureRecognizer.state == .recognized {
            
            let viewLocation = tapGestureRecognizer.location(in: metalView)
            let screenLocation = convertPointFromViewToScreen(viewLocation)
            let worldLocation = renderer.unproject(float4(screenLocation.x, screenLocation.y, 0.0, 1.0))
            
            destination = worldLocation.xy
            
            isAutonomous = true
            
            renderer.findPath(destination: destination, algorithm: "A*")
        }
    }

    // MARK: Path Planning
    
    /*@IBAction func setDestination(_ longPressGestureRecognizer: UILongPressGestureRecognizer) {
        
        guard ((renderer.content == .map) && (longPressGestureRecognizer.state == .began)) else {
//            NSLog("Gesture Ignored")
            return
        }
//        NSLog("Gesture Recognized")
        
        let destinationSettingController = self.storyboard!.instantiateViewController(withIdentifier: "DestinationSettingController") as! TableViewController
        
        destinationSettingController.delegate = self
        
        let popoverPresentationController = destinationSettingController.popoverPresentationController
        popoverPresentationController?.sourceView = metalView
        popoverPresentationController?.sourceRect = CGRect(origin: longPressGestureRecognizer.location(in: metalView), size: CGSize(width: 1, height: 1))
        
        present(destinationSettingController, animated: true, completion: nil)
        
        let destination = longPressGestureRecognizer.location(in: metalView)
        renderer.pathRenderer.destination = destination
    }
    
    @IBOutlet var cancelNavigationButton: UIButton!
    
    @IBAction func cancelNavigation(_ cancelNavigationButton: UIButton) {
        NSLog("Cancel Button Registered")
        renderer.content = .map
        cancelNavigationButton.isHidden = true
//        metalView.enableSetNeedsDisplay = false
//        metalView.isPaused = false
    }*/
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        
        return true
    }
    
    // MARK: - Autonomous destination
    
    var destination = float2()
    
    var isAutonomous = false
    
    // MARK: - Reset
    
    @IBAction func reset() {
        
        renderer.reset()
    }
}
