//
//  SmartCaseButton.swift
//  SmartCaseKit
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import Foundation
import Observation

/// A smart case button: an image index plus a background color
@Observable public class SmartCaseButton: Identifiable, Codable, CustomStringConvertible {
    public var id: UUID
    public var name: String
    public var description: String { "SmartCaseButton(id: \(id), name: \"\(name)\", imageIndex: \(imageIndex), red: \(backgroundRed), green: \(backgroundGreen), blue: \(backgroundBlue))" }
    public var imageIndex: UInt8
    public var backgroundRed: UInt8
    public var backgroundGreen: UInt8
    public var backgroundBlue: UInt8

    public init(
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

    enum CodingKeys: String, CodingKey {
        case id, name, imageIndex, backgroundRed, backgroundGreen, backgroundBlue
    }

    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageIndex = try container.decode(UInt8.self, forKey: .imageIndex)
        backgroundRed = try container.decode(UInt8.self, forKey: .backgroundRed)
        backgroundGreen = try container.decode(UInt8.self, forKey: .backgroundGreen)
        backgroundBlue = try container.decode(UInt8.self, forKey: .backgroundBlue)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(imageIndex, forKey: .imageIndex)
        try container.encode(backgroundRed, forKey: .backgroundRed)
        try container.encode(backgroundGreen, forKey: .backgroundGreen)
        try container.encode(backgroundBlue, forKey: .backgroundBlue)
    }
}

extension SmartCaseButton: Equatable {
    public static func == (lhs: SmartCaseButton, rhs: SmartCaseButton) -> Bool {
        lhs.id == rhs.id
    }
}

extension SmartCaseButton: Hashable {
    public func hash(into hasher: inout Hasher) {
        id.hash(into: &hasher)
    }
}
