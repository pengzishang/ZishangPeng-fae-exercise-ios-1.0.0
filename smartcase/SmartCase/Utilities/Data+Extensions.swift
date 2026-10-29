//
//  Data+Extensions.swift
//  SmartCase
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import Foundation

extension Data {
    /// Initialize with the raw bytes of any value
    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }

    /// Get integer value
    func to<T>(type: T.Type) -> T? where T: ExpressibleByIntegerLiteral {
        var value: T = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value) { copyBytes(to: $0) }
        return value
    }

    /// Self as a hex-encoded string
    var hexEncoded: String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}

extension String {
    /// The string, truncated to a given length
    func truncated(to length: Int, trailing: String = "…") -> String {
        guard count > length else { return self }
        let upToIndex = index(startIndex, offsetBy: length - 1 - trailing.count)
        return String(self[...upToIndex]) + trailing
    }
}
