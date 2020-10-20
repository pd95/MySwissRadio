//
//  Date+LocalizedString.swift
//  MyRadio
//
//  Created by Philipp on 14.10.20.
//

import Foundation

extension Date {

    static let localizedTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.formatterBehavior = .behavior10_4
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()

    var localizedTimeString: String {
        Self.localizedTimeFormatter.string(from: self)
    }
}
