//
//  UserDefaults+Extension.swift
//  MyRadio
//
//  Created by Philipp on 07.10.20.
//

import Foundation

extension UserDefaults {
    static let myDefaults = UserDefaults(suiteName: "MyRadio")!

    func setEncoded<T>(_ encodable: T, forKey key: String) throws where T: Codable {
        let data = try JSONEncoder().encode(encodable)
        self.setValue(data, forKey: key)
    }

    func getEncoded<T>(forKey key: String) -> T? where T: Codable {
        if let data = self.data(forKey: key) {
            return try? JSONDecoder().decode(T.self, from: data)
        }
        return nil
    }
}
