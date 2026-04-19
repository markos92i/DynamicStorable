//
//  Storable.swift
//  DynamicStorable
//
//  Created by Marcos del Castillo Camacho on 23/03/2026.
//

import SwiftUI

@propertyWrapper public struct Storable<T: Sendable>: DynamicProperty, Sendable {
    private let key: String
    private var url: URL?

    @State private var defaultValue: T
                
    public var wrappedValue: T {
        get {
            if let value = read() {
                return (try? Storable<T>.decode(value)) ?? defaultValue
            } else {
                return defaultValue
            }
        }
        nonmutating set {
            var hasValue = false
            if T.self is ExpressibleByNilLiteral.Type {
                if "\(newValue)" != "nil" { hasValue = true }
            } else {
                hasValue = true
            }

            if hasValue {
                try? write(Storable<T>.encode(newValue))
            } else {
                try? delete()
            }
            defaultValue = newValue
        }
    }
    
    public var projectedValue: Binding<T> { .init(get: { wrappedValue }, set: { wrappedValue = $0 }) }
    
    public init(wrappedValue: T, _ key: String) where T: Codable {
        self.key = key
        self.url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(key)

        if let url, let data = try? Data(contentsOf: url), let value = try? Storable<T>.decode(data) {
            _defaultValue = State(initialValue: value)
        } else {
            _defaultValue = State(initialValue: wrappedValue)
        }
    }

    private static func encode(_ value: T) throws -> Data {
        switch value {
        case let codable as Codable: try JSONEncoder().encode(codable)
        default: throw StorableError.conversionError
        }
    }
        
    private static func decode(_ data: Data) throws(StorableError) -> T {
        if let type = T.self as? Codable.Type {
            do {
                return try JSONDecoder().decode(type, from: data) as! T
            } catch {
                throw .conversionError
            }
        } else {
            throw .conversionError
        }
    }
    
    private func read() -> Data? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        
        return data
    }
    
    private func write(_ data: Data) throws {
        guard let url else { throw StorableError.saveError }
        
        try? data.write(to: url, options: .atomic)
    }
    
    private func delete() throws {
        guard let url else { throw StorableError.saveError }
        
        if FileManager.default.fileExists(atPath: url.path()) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

extension Storable where T: ExpressibleByNilLiteral {
    public init(_ key: String) where T: Codable {
        self.key = key
        self.url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(key)

        if let url, let data = try? Data(contentsOf: url), let value = try? Storable<T>.decode(data) {
            _defaultValue = State(initialValue: value)
        } else {
            _defaultValue = State(initialValue: nil)
        }
    }
}
