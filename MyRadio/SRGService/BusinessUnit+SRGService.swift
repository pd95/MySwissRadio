//
//  BusinessUnit.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation

extension BusinessUnit {
    init(from: SRGService.BusinessUnit) {
        self.init(rawValue: from.rawValue)!
    }

    var apiBusinessUnit: SRGService.BusinessUnit {
        SRGService.BusinessUnit(rawValue: self.rawValue)!
    }
}
