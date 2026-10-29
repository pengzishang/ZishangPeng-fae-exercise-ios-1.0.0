//
//  SmartCaseMessage.swift
//  SmartCaseKit
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import Foundation

public enum SmartCaseMessageType: UInt8 {
    case request = 0x00
    case response = 0x01
    case notification = 0x02
}

public enum SmartCaseMessageAction: UInt8 {
    case getButtons = 1
    case setButtonImage = 2
    case setButtonBackground = 3
    case buttonEvent = 0xff
}

/// A single SBSC protocol message
public struct SmartCaseMessage: CustomStringConvertible {
    public let id: UInt16
    public let type: SmartCaseMessageType
    public let action: SmartCaseMessageAction
    public let payload: Data

    /// Message status, if any
    public var status: UInt8? { payload[safe: 0] }

    /// Message serialized to data bytes
    public var data: Data {
        Data(from: id.littleEndian)
            + Data(from: type.rawValue)
            + Data(from: action.rawValue)
            + payload
    }

    /// Initialize from fields. Pass `id` only when replying to an existing request.
    public init(id: UInt16? = nil, type: SmartCaseMessageType, action: SmartCaseMessageAction, payload: Data = Data()) {
        self.id = id ?? Self.getNextRequestID()
        self.type = type
        self.action = action
        self.payload = payload
    }

    /// Initialize from serialized data bytes
    public init?(data: Data) {
        guard data.count >= 4 else {
            LogError("Too few bytes")
            return nil
        }
        guard let id: UInt16 = data[0...1].to(type: UInt16.self)?.littleEndian else {
            LogError("Cannot convert ID to UInt16")
            return nil
        }
        guard let type = SmartCaseMessageType(rawValue: data[2]) else {
            LogError("Cannot convert type to SmartCaseMessageType")
            return nil
        }
        guard let action = SmartCaseMessageAction(rawValue: data[3]) else {
            LogError("Cannot convert action to SmartCaseMessageAction")
            return nil
        }
        self.id = id
        self.type = type
        self.action = action
        self.payload = (data.count > 4) ? Data(data[4...]) : Data()
    }

    public var description: String {
        "SmartCaseMessage(id: \(self.id), type: \(self.type), action: \(self.action), payload: \(self.payload.hexEncoded.truncated(to: 64)))"
    }

    // MARK: - Internal

    private static var lastRequestID: UInt16 = 0

    private static func getNextRequestID() -> UInt16 {
        let result = Self.lastRequestID
        Self.lastRequestID += 1
        return result
    }
}
