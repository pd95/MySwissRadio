//
//  TimeInterval+Formatter.swift
//  MyRadio
//
//  Created by Philipp on 20.10.20.
//

import Foundation

private let relativeTimeIntervalFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .abbreviated
    formatter.allowedUnits = [.hour, .minute, .second]
    formatter.zeroFormattingBehavior = [.dropLeading]
    return formatter
}()

extension TimeInterval {

    var relativeTimeString: String {
        relativeTimeIntervalFormatter.string(from: self) ?? "(n/a)"
    }
}
