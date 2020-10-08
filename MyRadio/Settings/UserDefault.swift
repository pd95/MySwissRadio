//
//  UserDefault.swift
//  MyRadio
//
//  Created by Philipp on 08.10.20.
//

import Foundation

@propertyWrapper
struct UserDefault<Value> {

    let key: UserDefaults.SettingsKey
    let defaultValue: Value
    var storage: UserDefaults

    init(key: UserDefaults.SettingsKey, defaultValue: Value, storage: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }

    var wrappedValue: Value {
        get {
            let value: Value? = storage[key]
            return value ?? defaultValue
        }
        set {
            storage[key] = newValue
        }
    }
}

@propertyWrapper
struct CodableUserDefault<Value> where Value: Codable {

    let key: UserDefaults.SettingsKey
    let defaultValue: Value
    let storage: UserDefaults

    init(key: UserDefaults.SettingsKey, defaultValue: Value, storage: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.storage = storage
    }

    var wrappedValue: Value {
        get {
            guard let data: Data = storage[key],
                  let value = try? JSONDecoder().decode(Value.self, from: data) else {
                return defaultValue
            }
            return value
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            storage[key] = data
        }
    }
}
