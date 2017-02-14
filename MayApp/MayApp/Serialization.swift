//
//  Encodable.swift
//  MayApp
//
//  Created by Russell Ladd on 1/30/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import Foundation

// MARK: - JSON Serializable

public protocol JSONSerializable {
    
    init?(json: [String: Any])
    
    func json() -> [String: Any]
}

// MARK: - JSON Serializer

public protocol JSONSerializer {
    
    static var typeKey: String { get }
    
    static func identifier(for item: JSONSerializable) -> String?
    static func type(for identifier: String) -> JSONSerializable.Type?
}

extension JSONSerializer {
    
    public static func serialize(_ item: JSONSerializable) -> Data {
        
        var json = item.json()
        
        json[typeKey] = identifier(for: item)!
        
        return try! JSONSerialization.data(withJSONObject: json, options: [])
    }
    
    public static func deserialize(_ data: Data) -> JSONSerializable? {
        
        guard let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
            return nil
        }
        
        guard let typeString = json[typeKey] as? String else {
            return nil
        }
        
        guard let type = type(for: typeString) else {
            return nil
        }
        
        return type.init(json: json)
    }
}
