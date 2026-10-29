//
//  SmartCaseApp.swift
//  SmartCase
//
//  Created by Akos Polster on 10/06/2024.
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import SwiftUI

@main
struct SmartCaseApp: App {
    @State var smartCase = SmartCase.shared
    @State var smartCasePeripheral = SmartCasePeripheral.shared

    init() {
        smartCase.peripheral = smartCasePeripheral
    }

    var body: some Scene {
        WindowGroup {
            SmartCaseView()
        }
        .environment(smartCase)
    }
}
