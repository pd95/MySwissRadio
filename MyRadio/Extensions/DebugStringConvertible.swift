//
//  DebugStringConvertible.swift
//  MyRadio
//
//  Created by Philipp on 15.06.2025.
//

import Foundation
import AVFoundation

extension Optional: @retroactive CustomStringConvertible where Wrapped: CustomStringConvertible {
    public var description: String {
        map(\.description) ?? "nil"
    }
}

extension AVPlayerItem.Status: @retroactive CustomDebugStringConvertible {
    public var debugDescription: String {
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
