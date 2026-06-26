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
            guard let data = read() else { return defaultValue }
            guard let decoded: T = try? Storable<T>.decode(data) else {
                #if DEBUG
                print("⚠️ Storable: failed to decode '\(key)' — returning default")
                #endif
                return defaultValue
            }
            return decoded
        }
        nonmutating set {
            var hasValue = false
            if T.self is ExpressibleByNilLiteral.Type {
                if "\(newValue)" != "nil" { hasValue = true }
            } else {
                hasValue = true
            }

            if hasValue {
                if let data = try? Storable<T>.encode(newValue) {
                    write(data)
                }
            } else {
                delete()
            }
            defaultValue = newValue
        }
    }
    
    public var projectedValue: Binding<T> { .init(get: { wrappedValue }, set: { wrappedValue = $0 }) }
    
    // MARK: - Inits

    private init(wrappedValue: T, key: String) {
        self.key = key
        self.url = Self.storageURL(for: key)

        if let url, let data = try? Data(contentsOf: url), let value = try? Storable<T>.decode(data) {
            _defaultValue = State(initialValue: value)
        } else {
            _defaultValue = State(initialValue: wrappedValue)
        }
    }

    public init(wrappedValue: T, _ key: String) where T: Codable {
        self.init(wrappedValue: wrappedValue, key: key)
    }

    public init(wrappedValue: T, _ key: String) where T == Data {
        self.init(wrappedValue: wrappedValue, key: key)
    }

    #if canImport(UIKit)
    public init(wrappedValue: T, _ key: String) where T == UIImage {
        self.init(wrappedValue: wrappedValue, key: key)
    }

    public init(_ key: String) where T == UIImage? {
        self.key = key
        self.url = Self.storageURL(for: key)
        if let url, let data = try? Data(contentsOf: url), let value = try? Storable<T>.decode(data) {
            _defaultValue = State(initialValue: value)
        } else {
            _defaultValue = State(initialValue: nil)
        }
    }
    #endif

    // MARK: - Encoding

    private static func encode(_ value: T) throws -> Data {
        if let raw = value as? RawStorable { return raw.toData() }
        guard let codable = value as? Codable else { throw StorableError.conversionError }
        return try JSONEncoder().encode(codable)
    }
        
    private static func decode(_ data: Data) throws(StorableError) -> T {
        if let type = T.self as? RawStorable.Type {
            guard let value = type.fromData(data) as? T else { throw .conversionError }
            return value
        }
        if let optionalType = T.self as? AnyOptionalStorable.Type, let rawType = optionalType.wrappedStorableType {
            guard let value = rawType.fromData(data) as? T else { throw .conversionError }
            return value
        }
        guard let type = T.self as? Codable.Type else { throw .conversionError }
        do {
            return try JSONDecoder().decode(type, from: data) as! T
        } catch {
            throw .conversionError
        }
    }

    // MARK: - File I/O
    
    private static func storageURL(for key: String) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(key)
    }

    private func read() -> Data? {
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }
    
    private func write(_ data: Data) {
        guard let url else {
            #if DEBUG
            print("⚠️ Storable: failed to write '\(key)' — invalid URL")
            #endif
            return
        }
        try? data.write(to: url, options: .atomic)
    }
    
    private func delete() {
        guard let url, FileManager.default.fileExists(atPath: url.path()) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Optional support

extension Storable where T: ExpressibleByNilLiteral {
    private init(key: String) {
        self.key = key
        self.url = Self.storageURL(for: key)
        if let url, let data = try? Data(contentsOf: url), let value = try? Storable<T>.decode(data) {
            _defaultValue = State(initialValue: value)
        } else {
            _defaultValue = State(initialValue: nil)
        }
    }

    public init(_ key: String) where T: Codable {
        self.init(key: key)
    }

    public init(_ key: String) where T == Data? {
        self.init(key: key)
    }
}

// MARK: - Raw Storage Protocol

protocol RawStorable {
    func toData() -> Data
    static func fromData(_ data: Data) -> Self?
}

extension Data: RawStorable {
    func toData() -> Data { self }
    static func fromData(_ data: Data) -> Data? { data }
}

#if canImport(UIKit)
extension UIImage: RawStorable {
    func toData() -> Data { pngData() ?? Data() }
    static func fromData(_ data: Data) -> Self? { Self(data: data) }
}
#endif

// MARK: - Optional support for RawStorable

private protocol AnyOptionalStorable {
    static var wrappedStorableType: RawStorable.Type? { get }
}

extension Optional: AnyOptionalStorable {
    static var wrappedStorableType: RawStorable.Type? { Wrapped.self as? RawStorable.Type }
}
