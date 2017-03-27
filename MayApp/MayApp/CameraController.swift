//
//  CameraController.swift
//  MayApp
//
//  Created by Russell Ladd on 3/24/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

struct CameraColor {
    let r: UInt8
    let g: UInt8
    let b: UInt8
}

typealias CameraDepth = UInt16

struct CameraMeasurement {
    
    let video: Data
    let depth: Data
}

final class CameraController {
    
    let bufferCount = 640 * 480
    
    func measure() -> CameraMeasurement {
        
        var ts: UInt32 = 0
        
        var videoRawPointer: UnsafeMutableRawPointer? = nil
        freenect_sync_get_video(&videoRawPointer, &ts, 0, FREENECT_VIDEO_RGB)
        
        //let videoPointer = videoRawPointer?.assumingMemoryBound(to: CameraColor.self)
        //let videoBuffer = UnsafeBufferPointer(start: videoPointer, count: bufferCount)
        //let videoData = Data(buffer: videoBuffer)
        
        var depthRawPointer: UnsafeMutableRawPointer? = nil
        freenect_sync_get_depth(&depthRawPointer, &ts, 0, FREENECT_DEPTH_REGISTERED)
        
        //let depthPointer = depthRawPointer?.assumingMemoryBound(to: UInt16.self)
        //let depthBuffer = UnsafeBufferPointer(start: depthPointer, count: bufferCount)
        //let depthData = Data(buffer: depthBuffer)
        
        let videoData: Data
        if let videoRawPointer = videoRawPointer {
            videoData = Data(bytes: UnsafeRawPointer(videoRawPointer), count: bufferCount * MemoryLayout<CameraColor>.stride)
        } else {
            videoData = Array(repeating: CameraColor(r: 0, g: 0, b: 0), count: bufferCount).withUnsafeBufferPointer { buffer in Data(buffer: buffer) }
        }
        
        let depthData: Data
        if let depthRawPointer = depthRawPointer {
            depthData = Data(bytes: UnsafeRawPointer(depthRawPointer), count: bufferCount * MemoryLayout<CameraDepth>.stride)
        } else {
            depthData = Array(repeating: 0 as UInt16, count: bufferCount).withUnsafeBufferPointer { buffer in Data(buffer: buffer) }
        }
        
        //let videoData = Data(bytesNoCopy: video!, count: 3 * 480 * 640, deallocator: .none)
        //let depthData = Data(bytesNoCopy: depth!, count: 2 * 480 * 640, deallocator: .none)
        
        return CameraMeasurement(video: videoData, depth: depthData)
    }
}
