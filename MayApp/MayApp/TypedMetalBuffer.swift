//
//  TypedMetalBuffer.swift
//  MayApp
//
//  Created by Russell Ladd on 4/3/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Metal

final class TypedMetalBuffer<Element>: RandomAccessCollection, MutableCollection {
    
    // MARK: Storage
    
    private(set) var metalBuffer: MTLBuffer
    
    private(set) var pointer: UnsafeMutablePointer<Element>
    private(set) var buffer: UnsafeMutableBufferPointer<Element>
    
    // MARK: Capacity
    
    var capacity: Int {
        return buffer.count
    }
    
    // MARK: Initialization
    
    init(device: MTLDevice, capacity: Int = 1) {
        
        guard capacity > 0 else {
            preconditionFailure("Capacity must be greater than zero.")
        }
        
        self.metalBuffer = device.makeBuffer(length: capacity * MemoryLayout<Element>.stride, options: [])
        
        self.pointer = metalBuffer.contents().assumingMemoryBound(to: Element.self)
        self.buffer = UnsafeMutableBufferPointer(start: pointer, count: capacity)
    }
    
    // MARK: Collection
    
    var startIndex: Int {
        return 0
    }
    
    var endIndex = 0
    
    subscript(i: Int) -> Element {
        get {
            return buffer[i]
        }
        set(element) {
            buffer[i] = element
        }
    }
    
    func index(before i: Int) -> Int {
        return buffer.index(before: i)
    }
    
    func index(after i: Int) -> Int {
        return buffer.index(after: i)
    }
    
    // MARK: Mutating
    
    func grow(to capacity: Int) {
        
        guard capacity > self.capacity else {
            return
        }
        
        let newMetalBuffer = metalBuffer.device.makeBuffer(length: capacity * MemoryLayout<Element>.stride, options: [])
        
        let newPointer = newMetalBuffer.contents().assumingMemoryBound(to: Element.self)
        newPointer.assign(from: UnsafePointer(pointer), count: count)
        
        self.metalBuffer = newMetalBuffer
        
        self.pointer = newPointer
        self.buffer = UnsafeMutableBufferPointer(start: pointer, count: capacity)
    }
    
    func append(_ element: Element) {
        
        if count == capacity {
            grow(to: count * 2)
            print("Grow to \(count * 2)")
        }
        
        buffer[count] = element
        endIndex += 1
    }
    
    func removeAll() {
        
        endIndex = 0
    }
}
