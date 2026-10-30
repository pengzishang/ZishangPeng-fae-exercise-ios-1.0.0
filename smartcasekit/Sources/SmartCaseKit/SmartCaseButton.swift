//
//  SmartCaseButton.swift
//  SmartCaseKit
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import Foundation
import Observation

/// One button on a smart case: an icon plus a background color.
///
/// After you connect, you get the buttons from `SmartCaseDevice.buttons`. A case always has 4 buttons.
///
/// **Changing these values does not change the device.** These are copies in your own memory.
/// Nothing is sent to the case automatically. To change the real device, call:
/// - `SmartCaseDevice.setButtonImage(index:imageIndex:)` for the icon only
/// - `SmartCaseDevice.setButton(index:imageIndex:red:green:blue:)` for icon and color
///
/// The `index` there is the position of the button, `0` to `3`.
///
/// ## How the values map to protocol bytes
///
/// See `sbsc-protocol.md`. Each button is 4 bytes in a row: image index, red, green and blue,
/// one byte each. That is exactly the four properties below, so no conversion is needed.
/// `name` and `id` have no bytes in the protocol. They are local only and cannot be sent.
@Observable public class SmartCaseButton: Identifiable, Codable, CustomStringConvertible {
    /// The unique number of this button. Local only.
    ///
    /// The protocol has no such field. Do not use it as the argument of `setButton(index:...)`,
    /// which wants the button position `0` to `3`.
    public var id: UUID
    /// The name of the button, for example "Left". Only your app sees it. It can be empty.
    public var name: String
    /// A one-line summary of all fields, for logging.
    public var description: String { "SmartCaseButton(id: \(id), name: \"\(name)\", imageIndex: \(imageIndex), red: \(backgroundRed), green: \(backgroundGreen), blue: \(backgroundBlue))" }
    /// Which icon the button shows. Use `0` to `15` (the firmware has 16 icons). Default is `0`.
    ///
    /// Values outside that range cannot be shown by the device. The sample apps wrap around
    /// with `value % 16`, so `16` shows icon 0 and `17` shows icon 1.
    /// In the protocol this is 1 byte, used by `SetButtonImage` (Action 0x02).
    public var imageIndex: UInt8
    /// The red part of the background color, `0` to `255`. Default is `32`. Green and blue work
    /// the same way, and the three values together are the background color.
    ///
    /// All three at 0 is black, all three at 255 is white. These are whole numbers, not the
    /// `0.0` to `1.0` decimals that SwiftUI `Color(red:green:blue:)` uses — multiply by 255
    /// to convert. In the protocol each color is 1 byte, used by `SetButtonBackground` (Action 0x03).
    public var backgroundRed: UInt8
    /// The green part of the background color, `0` to `255`. Default is `32`. Same as `backgroundRed`.
    public var backgroundGreen: UInt8
    /// The blue part of the background color, `0` to `255`. Default is `32`. Same as `backgroundRed`.
    public var backgroundBlue: UInt8

    /// Creates a button. Every argument is optional, so `SmartCaseButton()` alone gives you
    /// a ready-to-use default button.
    ///
    /// - Parameters:
    ///   - id: Unique number, local only. A new one is generated if you pass nothing.
    ///   - name: A label only your app sees. Empty by default.
    ///   - imageIndex: Which icon to show, `0` to `15`. Default `0`.
    ///   - backgroundRed / backgroundGreen / backgroundBlue: The three color parts, `0` to `255`.
    ///     All default to `32`, which is dark grey.
    ///
    /// Creating or changing a button here does not change the real device. Use
    /// `SmartCaseDevice.setButton(...)` for that.
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
