//
//  Logging.swift
//  App
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import Foundation
import os

/// Log a trace message to the console (debug builds only)
func Log(_ msg: String = "", _ file: NSString = #file, _ function: String = #function, _ line: UInt = #line) {
    AppLogger.log(msg, file, function, line)
}

/// App's own minimal logger, built on os.Logger
enum AppLogger {
    static func log(_ msg: String, _ file: NSString, _ function: String, _ line: UInt) {
#if DEBUG
        logger.log("\(baseName(of: file)):\(function):\(line): \(msg)")
#endif
    }

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.bragi.App", category: "App")

    private static func baseName(of file: NSString) -> String {
        file.lastPathComponent.replacingOccurrences(of: ".swift", with: "")
    }
}
