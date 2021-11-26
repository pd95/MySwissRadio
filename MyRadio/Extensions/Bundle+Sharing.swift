//
//  Bundle+Sharing.swift
//  MyRadio
//
//  Created by Philipp on 09.10.20.
//

import Foundation
import os.log

extension Bundle {

    /// Returns the app group identifier, based either on the "APP_GROUP_IDENTIFIER" entry in Info.plist or if missing, derived from the bundle identifier
    /// by dropping the last part and prepending "group."
    static let appGroupIdentifier: String = {
        let identifier: String
        if let infoPlist = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_IDENTIFIER") as? String,
           infoPlist.isEmpty == false {
            identifier = infoPlist
            Logger().info("Populated appGroupIdentifier \(identifier) from Info.plist")
        } else {
            let mainIdentifier = Bundle.main.bundleIdentifier?.split(separator: ".").dropLast().joined(separator: ".")
            identifier = "group.\(mainIdentifier ?? "invalid.bundleIdentifier")"
            Logger().info("Derived appGroupIdentifier \(identifier) from bundleIdentifier")
        }
        return identifier
    }()
}
