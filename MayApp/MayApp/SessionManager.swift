//
//  SessionManager.swift
//  MayApp
//
//  Created by Russell Ladd on 1/27/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import MultipeerConnectivity

protocol SessionDataReceiver {
    
    func receive<T>(_ item: T)
}

protocol SessionManagerDelegate: class {
    
    func session(_ session: SessionManager, peer: MCPeerID, didChange state: MCSessionState)
}

final class SessionManager: NSObject, MCSessionDelegate {
    
    let peer: MCPeerID
    let session: MCSession
    
    let serializer: JSONSerializer.Type
    let receiver: SessionDataReceiver
    
    weak var delegate: SessionManagerDelegate?
    
    init(peer: MCPeerID, serializer: JSONSerializer.Type, receiver: SessionDataReceiver) {
        
        self.peer = peer
        self.session = MCSession(peer: peer)
        
        self.serializer = serializer
        self.receiver = receiver
        
        super.init()
        
        self.session.delegate = self
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        DispatchQueue.main.async {
            self.delegate?.session(self, peer: peerID, didChange: state)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        guard let item = serializer.deserialize(data) else {
            return
        }
        
        DispatchQueue.main.async {
            self.receiver.receive(item)
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
    
    func send<T: JSONSerializable>(_ item: T) {
        
        let data = serializer.serialize(item)
        
        try? session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    }
}
