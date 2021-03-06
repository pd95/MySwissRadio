//
//  BusinessUnit.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation

enum BusinessUnit: String, CustomStringConvertible, CaseIterable, Codable {
    case srf = "SRF", rts = "RTS", rsi = "RSI", rtr = "RTR"

    var description: String {
        rawValue
    }
}

extension BusinessUnit: Comparable {
    static func sortOrder(of bu: BusinessUnit) -> Int {
        allCases.firstIndex(of: bu) ?? -1
    }

    static func < (lhs: BusinessUnit, rhs: BusinessUnit) -> Bool {
        sortOrder(of: lhs) < sortOrder(of: rhs)
    }
}
