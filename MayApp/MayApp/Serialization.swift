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

public protocol DataSerializable {
    
    init?(from: MutableRandomAccessSlice<Data>)
    
    var byteCount: Int { get }
    
    func write(to: MutableRandomAccessSlice<Data>)
}

// MARK: - JSON Serializer

public protocol JSONSerializer {
    
    static var typeKey: String { get }
    
    static func identifier(for item: JSONSerializable) -> String?
    static func type(for identifier: String) -> JSONSerializable.Type?
}

public protocol DataSerializer {
    
    static func identifier(for item: DataSerializable) -> UInt8?
    static func type(for identifier: UInt8) -> DataSerializable.Type?
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

extension DataSerializer {
    
    public static func serialize(_ item: DataSerializable) -> Data {
        
        let identifierByteCount = MemoryLayout<UInt8>.size
        
        let byteCount = identifierByteCount + item.byteCount
        
        var data = Data(count: byteCount)
        
        data[0] = identifier(for: item)!
        item.write(to: data[identifierByteCount..<data.endIndex])
        
        return data
    }
    
    public static func deserialize(_ data: Data) -> DataSerializable? {
        
        let identifierByteCount = MemoryLayout<UInt8>.size
        
        guard data.count >= identifierByteCount else {
            return nil
        }
        
        guard let type = type(for: data[0]) else {
            return nil
        }
        
        return type.init(from: data[0..<data.endIndex])
    }
}
