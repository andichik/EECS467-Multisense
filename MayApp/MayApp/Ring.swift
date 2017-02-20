//
//  Ring.swift
//  MayApp
//
//  Created by Russell Ladd on 2/16/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

struct Ring<Element> {
    
    private var array: [Element]
    
    private var currentIndex = 0
    
    private var nextIndex: Int {
        return (currentIndex + 1) % array.count
    }
    
    init(_ array: [Element]) {
        
        precondition(array.count >= 2)
        
        self.array = array
    }
    
    init(repeating element: @autoclosure () -> Element, count: Int) {
        
        precondition(count >= 2)
        
        array = []
        
        for _ in 0..<count {
            array.append(element())
        }
    }
    
    var current: Element {
        return array[currentIndex]
    }
    
    var next: Element {
        return array[nextIndex]
    }
    
    mutating func rotate() {
        currentIndex = nextIndex
    }
    
    var count: Int {
        return array.count
    }
}
