//
//  DebugStringConvertible.swift
//  MyRadio
//
//  Created by Philipp on 15.06.2025.
//

import AVFoundation
import Foundation

extension Optional where Wrapped: CustomStringConvertible {
    var descriptionOrNil: String {
        map(\.description) ?? "nil"
    }
}

extension AVPlayerItem.Status {
    var debugString: String {
        switch self {
        case .readyToPlay:
            return "readyToPlay"
        case .failed:
            return "failed"
        case .unknown:
            return "unknown"
        @unknown default:
            return "unknown(\(rawValue))"
        }
    }
}
