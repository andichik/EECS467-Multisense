//
//  Pairs.swift
//  MayApp
//
//  Created by Russell Ladd on 4/14/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

extension Int {
    
    var factorial: Int {
        
        if self == 0 {
            return 1
        } else {
            return self * (self - 1).factorial
        }
    }
}

extension Collection {
    
    func forEachPair(_ body: (Iterator.Element, Iterator.Element) -> Void) {
        
        var index1 = startIndex
        
        while index1 != endIndex {
            
            var index2 = index(after: index1)
            
            while index2 != endIndex {
                
                body(self[index1], self[index2])
                
                formIndex(after: &index2)
            }
            
            formIndex(after: &index1)
        }
    }
    
    func closest<Distance>(_ distance: (Iterator.Element) -> Distance) -> (index: Int, element: Iterator.Element, distance: Distance)?
        where Distance: Comparable {
        
        return enumerated().reduce(nil) { result, next in
            
            let d = distance(next.element)
            
            guard let result = result else {
                return (next.offset, next.element, d)
            }
            
            if d < result.distance {
                return (next.offset, next.element, d)
            } else {
                return result
            }
        }
    }
    
    func mapPairs<Result>(_ body: (Iterator.Element, Iterator.Element) -> Result) -> [Result] {
        
        var results = Array<Result>()
        
        forEachPair { results.append(body($0, $1)) }
        
        return results
    }
}
