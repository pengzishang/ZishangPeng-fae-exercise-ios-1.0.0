//
//  SmartCaseButton.swift
//  SmartCase
//
//  Created by Akos Polster on 10/06/2024.
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import Foundation
import SwiftUI

/// An SVG-based smart case button
@Observable class SmartCaseButton: Identifiable, Codable {
    var id: UUID
    var name: String
    var imageIndex: UInt8
    var backgroundRed: UInt8
    var backgroundGreen: UInt8
    var backgroundBlue: UInt8

    init(
        id: UUID = UUID(),
        name: String = "",
        imageIndex: UInt8 = 0,
        backgroundRed: UInt8 = 32,
        backgroundGreen: UInt8 = 32,
        backgroundBlue: UInt8 = 32
    ) {
        self.id = id
        self.name = name
        self.imageIndex = imageIndex
        self.backgroundRed = backgroundRed
        self.backgroundGreen = backgroundGreen
        self.backgroundBlue = backgroundBlue
    }

    // Written by hand because the @Observable macro's synthesized _$observationRegistrar
    // defeats compiler-synthesized Codable conformance.
    enum CodingKeys: String, CodingKey {
        case id, name, imageIndex, backgroundRed, backgroundGreen, backgroundBlue
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageIndex = try container.decode(UInt8.self, forKey: .imageIndex)
        backgroundRed = try container.decode(UInt8.self, forKey: .backgroundRed)
        backgroundGreen = try container.decode(UInt8.self, forKey: .backgroundGreen)
        backgroundBlue = try container.decode(UInt8.self, forKey: .backgroundBlue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(imageIndex, forKey: .imageIndex)
        try container.encode(backgroundRed, forKey: .backgroundRed)
        try container.encode(backgroundGreen, forKey: .backgroundGreen)
        try container.encode(backgroundBlue, forKey: .backgroundBlue)
    }
}
