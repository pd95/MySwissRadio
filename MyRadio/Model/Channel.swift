//
//  Channel.swift
//  MyRadio
//
//  Created by Philipp on 06.10.20.
//

import Foundation

struct Channel: Identifiable, Codable {
    let id: UUID
    let name: String
    let imageURL: URL
}

