//
//  Persistent.swift
//  SmartCase
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import Foundation

private let persistentEncoder = JSONEncoder()
private let persistentDecoder = JSONDecoder()

/// Wrapper for persistent properties stored in UserDefaults
@propertyWrapper
struct Persistent<T: Codable> {
    let key: String
    let defaultValue: T
    let defaults: UserDefaults

    private struct Box: Codable {
        let value: T?
    }

    init(key: String, defaultValue: T, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.defaults = defaults
    }

    var wrappedValue: T {
        get {
            guard let data = defaults.data(forKey: key) else { return defaultValue }
            do {
                let boxed = try persistentDecoder.decode(Box.self, from: data)
                return boxed.value ?? defaultValue
            } catch {
                LogError(error)
                return defaultValue
            }
        }
        set {
            let boxed = Box(value: newValue)
            defaults.set(try? persistentEncoder.encode(boxed), forKey: key)
        }
    }
}
