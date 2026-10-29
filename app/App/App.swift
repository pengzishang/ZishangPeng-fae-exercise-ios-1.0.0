//
//  App.swift
//  App
//
//  Created by Akos Polster on 11/06/2024.
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import SwiftUI
import SmartCaseKit

@main
struct SmartCaseApp: App {
    @State var deviceManager = SmartCaseDeviceManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(deviceManager)
        }
    }
}
