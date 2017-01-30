//
//  Peer.swift
//  SharedMusic
//
//  Created by Russell Ladd on 10/31/16.
//  Copyright © 2016 GRL5. All rights reserved.
//

import Foundation
import MultipeerConnectivity

#if os(iOS)
    import UIKit
#elseif os(macOS)
    import SystemConfiguration
#endif

extension MCPeerID {
    
    static let shared: MCPeerID = {
        
        let key = "com.EECS467.MayApp.peer"
        
        let peer: MCPeerID
        
        if let savedPeerData = UserDefaults.standard.data(forKey: key), let savedPeer = NSKeyedUnarchiver.unarchiveObject(with: savedPeerData) as? MCPeerID {
            
            peer = savedPeer
            
        } else {
            
            #if os(iOS)
                let name = UIDevice.current.name
            #elseif os(macOS)
                let name = (SCDynamicStoreCopyComputerName(nil, nil) as? String) ?? "Laptop"
            #endif
            
            peer = MCPeerID(displayName: name)
            
            let peerData = NSKeyedArchiver.archivedData(withRootObject: peer)
            
            UserDefaults.standard.set(peerData, forKey: key)
        }
        
        return peer
    }()
}
