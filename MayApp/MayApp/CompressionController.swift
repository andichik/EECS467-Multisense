//
//  CompressionController.swift
//  MayApp
//
//  Created by Russell Ladd on 4/18/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation
import VideoToolbox
import CoreVideo

public final class CompressionController {
    
    let compressionSession: VTCompressionSession
    
    let pixelBufferPool: CVPixelBufferPool
    
    var time = 0.0
    let timeInterval: Double
    
    public init(timeInterval: Double) {
        
        // Test code for compression
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_24RGB,
                          kCVPixelBufferWidthKey as String: Camera.width,
                          kCVPixelBufferHeightKey as String: Camera.height] as CFDictionary
        
        var compressionSession: VTCompressionSession? = nil
        
        VTCompressionSessionCreate(nil, Int32(Camera.width), Int32(Camera.height), kCMVideoCodecType_H264, nil, attributes, nil, nil, nil, &compressionSession)
        
        self.compressionSession = compressionSession!
        
        self.pixelBufferPool = VTCompressionSessionGetPixelBufferPool(compressionSession!)!
        
        self.timeInterval = timeInterval
    }
    
    public func compress(_ data: Data, completionHandler: @escaping (Data) -> Void) {
        
        time += timeInterval
        
        var pixelBuffer: CVPixelBuffer? = nil
        
        CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, [])
        
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer!)!
        
        data.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in
            let rawPointer = UnsafeRawPointer(pointer)
            baseAddress.copyBytes(from: rawPointer, count: data.count)
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, [])
        
        let presentationTime = CMTime(seconds: time, preferredTimescale: 600)
        let duration = CMTime(seconds: 0.1, preferredTimescale: 600)
        
        VTCompressionSessionEncodeFrameWithOutputHandler(compressionSession, pixelBuffer!, presentationTime, duration, nil, nil) { status, info, sampleBuffer in
            
            /*let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer!)!
            
            var dataLength = 0
            var dataPointer: UnsafeMutablePointer<Int8>? = nil
            
            CMBlockBufferGetDataPointer(blockBuffer, 0, nil, &dataLength, &dataPointer)
            
            let buffer = UnsafeBufferPointer(start: dataPointer, count: dataLength)
            
            let compressedData = Data(buffer: buffer)
            
            completionHandler(compressedData)*/
            
            print ("Received encoded frame in delegate...")
            
            guard let sampleBuffer = sampleBuffer else {
                return
            }
            
            //----AVCC to Elem stream-----//
            var elementaryStream = Data()
            
            //1. check if CMBuffer had I-frame
            var isIFrame = false
            let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false)!
            
            //check how many attachments
            if CFArrayGetCount(attachmentsArray) > 0 {
                
                let dict = CFArrayGetValueAtIndex(attachmentsArray, 0)
                let dictRef: CFDictionary = unsafeBitCast(dict, to: CFDictionary.self)
                //get value
                let value = CFDictionaryGetValue(dictRef, unsafeBitCast(kCMSampleAttachmentKey_NotSync, to: UnsafeRawPointer.self))
                if ( value != nil ){
                    print ("IFrame found...")
                    isIFrame = true
                }
            }
            
            //2. define the start code
            //let nStartCodeLength = 4
            let nStartCode: [UInt8] = [0x00, 0x00, 0x00, 0x01]
            
            //3. write the SPS and PPS before I-frame
            if isIFrame == true {
                
                let description = CMSampleBufferGetFormatDescription(sampleBuffer)!
                //how many params
                var numParams = 0
                CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, 0, nil, nil, &numParams, nil)
                
                //write each param-set to elementary stream
                print("Write param to elementaryStream ", numParams)
                for i in 0..<numParams {
                    
                    var parameterSetPointer: UnsafePointer<UInt8>? = nil
                    var parameterSetLength = 0
                    CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, i, &parameterSetPointer, &parameterSetLength, nil, nil)
                    
                    elementaryStream.append(contentsOf: nStartCode)
                    elementaryStream.append(parameterSetPointer!, count: parameterSetLength)
                }
            }
            
            //4. Get a pointer to the raw AVCC NAL unit data in the sample buffer
            var blockBufferLength = 0
            var bufferDataPointer: UnsafeMutablePointer<Int8>? = nil
            CMBlockBufferGetDataPointer(CMSampleBufferGetDataBuffer(sampleBuffer)!, 0, nil, &blockBufferLength, &bufferDataPointer)
            print ("Block length = ", blockBufferLength)
            
            //5. Loop through all the NAL units in the block buffer
            var bufferOffset = 0
            let AVCCHeaderLength = 4
            
            while bufferOffset < (blockBufferLength - AVCCHeaderLength) {
                // Read the NAL unit length
                var NALUnitLength: UInt32 =  0
                memcpy(&NALUnitLength, bufferDataPointer! + bufferOffset, AVCCHeaderLength)
                //Big-Endian to Little-Endian
                NALUnitLength = CFSwapInt32(NALUnitLength)
                
                if NALUnitLength > 0 {
                    
                    print ( "NALUnitLen = ", NALUnitLength)
                    // Write start code to the elementary stream
                    elementaryStream.append(contentsOf: nStartCode)
                    // Write the NAL unit without the AVCC length header to the elementary stream
                    
                    UnsafePointer(bufferDataPointer!).withMemoryRebound(to: UInt8.self, capacity: Int(NALUnitLength)) { body in
                        elementaryStream.append(body + bufferOffset + AVCCHeaderLength, count: Int(NALUnitLength))
                    }
                    
                    // Move to the next NAL unit in the block buffer
                    bufferOffset += AVCCHeaderLength + size_t(NALUnitLength);
                    print("Moving to next NALU...")
                }
            }
            
            print("Read completed...")
            completionHandler(elementaryStream)
        }
    }
}

// This is interesting: https://github.com/shogo4405/lf.swift
// Another one: https://github.com/tidwall/Avios/blob/master/Avios/NALU.swift
// SO Decompression: http://stackoverflow.com/questions/29525000/how-to-use-videotoolbox-to-decompress-h-264-video-stream
// SO Compression: http://stackoverflow.com/questions/28396622/extracting-h264-from-cmblockbuffer
// Pixel formats: https://developer.apple.com/reference/corevideo/cvpixelformatdescription/1563591-pixel_format_types
// Codecs: https://developer.apple.com/reference/coremedia/cmvideocodectype?language=objc
// Annex B vs AVCC: http://stackoverflow.com/questions/24884827/possible-locations-for-sequence-picture-parameter-sets-for-h-264-stream/24890903#24890903
// Warren Moore CMTime: https://warrenmoore.net/understanding-cmtime
// How good is H264: https://sidbala.com/h-264-is-magic/


/*public final class DecompressionController {
    
    let decompressionSession: VTDecompressionSession
    
    var videoFormatDescription: CMVideoFormatDescription? = nil
    
    public init() {
        
        // Test code for compression
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_128RGBAFloat,
                          kCVPixelBufferWidthKey as String: Camera.width,
                          kCVPixelBufferHeightKey as String: Camera.height,
                          kCVPixelBufferMetalCompatibilityKey as String: true] as CFDictionary
        
        var videoFormatDescription: CMVideoFormatDescription? = nil
        
        CMVideoFormatDescriptionCreate(nil, kCMVideoCodecType_H264, Int32(Camera.width), Int32(Camera.height), nil, &videoFormatDescription)
        
        self.videoFormatDescription = videoFormatDescription!
        
        var decompressionSession: VTDecompressionSession? = nil
        
        VTDecompressionSessionCreate(nil, self.videoFormatDescription, nil, attributes, nil, &decompressionSession)
        
        self.decompressionSession = decompressionSession!
    }
    
    public func decompress(_ data: Data, completionHandler: @escaping (Data) -> Void) {
        
        CMBlockBufferCreateContiguous(<#T##structureAllocator: CFAllocator?##CFAllocator?#>, <#T##sourceBuffer: CMBlockBuffer##CMBlockBuffer#>, <#T##blockAllocator: CFAllocator?##CFAllocator?#>, <#T##customBlockSource: UnsafePointer<CMBlockBufferCustomBlockSource>?##UnsafePointer<CMBlockBufferCustomBlockSource>?#>, <#T##offsetToData: Int##Int#>, <#T##dataLength: Int##Int#>, <#T##flags: CMBlockBufferFlags##CMBlockBufferFlags#>, <#T##newBBufOut: UnsafeMutablePointer<CMBlockBuffer?>##UnsafeMutablePointer<CMBlockBuffer?>#>)
        
        CMSampleBufferCreate(nil, <#T##dataBuffer: CMBlockBuffer?##CMBlockBuffer?#>, <#T##dataReady: Bool##Bool#>, <#T##makeDataReadyCallback: CMSampleBufferMakeDataReadyCallback?##CMSampleBufferMakeDataReadyCallback?##(CMSampleBuffer, UnsafeMutableRawPointer?) -> OSStatus#>, <#T##makeDataReadyRefcon: UnsafeMutableRawPointer?##UnsafeMutableRawPointer?#>, <#T##formatDescription: CMFormatDescription?##CMFormatDescription?#>, <#T##numSamples: CMItemCount##CMItemCount#>, <#T##numSampleTimingEntries: CMItemCount##CMItemCount#>, <#T##sampleTimingArray: UnsafePointer<CMSampleTimingInfo>?##UnsafePointer<CMSampleTimingInfo>?#>, <#T##numSampleSizeEntries: CMItemCount##CMItemCount#>, <#T##sampleSizeArray: UnsafePointer<Int>?##UnsafePointer<Int>?#>, <#T##sBufOut: UnsafeMutablePointer<CMSampleBuffer?>##UnsafeMutablePointer<CMSampleBuffer?>#>)
        
        VTDecompressionSessionDecodeFrameWithOutputHandler(decompressionSession, <#T##sampleBuffer: CMSampleBuffer##CMSampleBuffer#>, <#T##decodeFlags: VTDecodeFrameFlags##VTDecodeFrameFlags#>, <#T##infoFlagsOut: UnsafeMutablePointer<VTDecodeInfoFlags>?##UnsafeMutablePointer<VTDecodeInfoFlags>?#>, <#T##outputHandler: VTDecompressionOutputHandler##VTDecompressionOutputHandler##(OSStatus, VTDecodeInfoFlags, CVImageBuffer?, CMTime, CMTime) -> Void#>)
    }
}*/

