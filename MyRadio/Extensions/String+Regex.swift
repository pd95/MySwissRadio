//
//  String+Regex.swift
//  MyRadio
//
//  Created by Philipp on 13.10.20.
//

import Foundation

extension String {

    /// Matches string with a regular expression, returning an array of `String`
    ///
    ///     html.matches(regex: "http(s)://.*/([a-z0-9]+).jpg")
    ///
    /// - Parameter regex: Regular expression to be matched
    /// - Parameter options: options passed to `NSRegularExpression`
    /// - Returns: Array with all matches and regex groups
    func matches(regex: String, options: NSRegularExpression.Options = []) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: regex, options: options) else { return [] }
        let matches  = regex.matches(in: self, options: [], range: NSRange(self.startIndex..., in: self))
        return matches.reduce([]) { res, match in
            var newRes = res
            for index in 0..<match.numberOfRanges {
                let matchedString = String(self[Range(match.range(at: index), in: self)!])
                newRes.append(matchedString)
            }
            return newRes
        }
    }
}
