//
//  BusinessUnit.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation

extension BusinessUnit {
    init(from: SRGService.BusinessUnits) {
        self.init(rawValue: from.rawValue)!
    }

    var apiBusinessUnit: SRGService.BusinessUnits {
        SRGService.BusinessUnits(rawValue: self.rawValue)!
    }
}
