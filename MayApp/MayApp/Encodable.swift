//
//  Encodable.swift
//  MayApp
//
//  Created by Russell Ladd on 1/30/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

// MARK: - Encodable

protocol Encodable {
    
    init?(data: Data)
    
    func encoded() -> Data
}

// MARK: - JSONEncodable

protocol JSONEncodable: Encodable {
    
    init?(jsonData: [String: Any])
    
    func encodedJSON() -> [String: Any]
}

extension JSONEncodable {
    
    init?(data: Data) {
        
        guard let jsonData = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return nil
        }
        
        self.init(jsonData: jsonData)
    }
    
    func encoded() -> Data {
        
        return try! JSONSerialization.data(withJSONObject: encodedJSON(), options: [])
    }
}

// MARK: - TypedJSONEncodable

enum TypedJSONEncodableKey: String {
    case type = "t"
}

protocol TypedJSONEncodable: JSONEncodable {
    
    func encodedJSONProperties() -> [String: Any]
    
    static var type: String { get }
}

extension TypedJSONEncodable {
    
    func encodedJSON() -> [String : Any] {
        
        var json = encodedJSONProperties()
        json[TypedJSONEncodableKey.type.rawValue] = Self.type
        
        return json
    }
}

protocol JSONEncodableTyper {
    
    static func type(for identifer: String) -> TypedJSONEncodable.Type?
}

extension JSONEncodableTyper {
    
    static func decode(_ data: Data) -> TypedJSONEncodable? {
        
        guard let jsonData = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return nil
        }
        
        guard let typeString = jsonData[TypedJSONEncodableKey.type.rawValue] as? String else {
            return nil
        }
        
        guard let type = type(for: typeString) else {
            return nil
        }
        
        return type.init(jsonData: jsonData)
    }
}
