// swift-tools-version:5.10
//
//  Package.swift
//  SmartCaseKit
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import PackageDescription

let package = Package(
    name: "SmartCaseKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SmartCaseKit",
            targets: ["SmartCaseKit"]),
    ],
    targets: [
        .target(
            name: "SmartCaseKit"),
        .testTarget(
            name: "SmartCaseKitTests",
            dependencies: ["SmartCaseKit"]),
    ]
)
