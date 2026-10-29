//
//  Logging.swift
//  SmartCase
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import Foundation
import os

/// Log a trace message to the console (debug builds only)
func Log(_ msg: String = "", _ file: NSString = #file, _ function: String = #function, _ line: UInt = #line) {
    SmartCaseLogger.log(msg, file, function, line)
}

/// Log anything to the console (debug builds only)
func Log(_ any: Any, _ file: NSString = #file, _ function: String = #function, _ line: UInt = #line) {
    SmartCaseLogger.log("\(any)", file, function, line)
}

/// Log an error to the console
func LogError(_ msg: String = "", _ file: NSString = #file, _ function: String = #function, _ line: UInt = #line) {
    SmartCaseLogger.logError(msg, file, function, line)
}

/// Log any error to the console
func LogError(_ any: Any, _ file: NSString = #file, _ function: String = #function, _ line: UInt = #line) {
    SmartCaseLogger.logError("\(any)", file, function, line)
}

/// SmartCase's own minimal logger, built on os.Logger
enum SmartCaseLogger {
    static func log(_ msg: String, _ file: NSString, _ function: String, _ line: UInt) {
#if DEBUG
        logger.log("\(baseName(of: file)):\(function):\(line): \(msg)")
#endif
    }

    static func logError(_ msg: String, _ file: NSString, _ function: String, _ line: UInt) {
        logger.error("\(baseName(of: file)):\(function):\(line): ❌ \(msg)")
    }

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bragi.SmartCase", category: "SmartCase")

    private static func baseName(of file: NSString) -> String {
        file.lastPathComponent.replacingOccurrences(of: ".swift", with: "")
    }
}
