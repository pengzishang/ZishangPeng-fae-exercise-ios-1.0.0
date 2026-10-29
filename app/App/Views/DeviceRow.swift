//
//  DeviceRow.swift
//  App
//
//  Created by Akos Polster on 11/06/2024.
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import SwiftUI
import SmartCaseKit

/// Displays a device in a device list
struct DeviceRow: View {
    var device: SmartCaseDevice

    var body: some View {
        HStack() {
            device.image
            VStack(alignment: .leading) {
                Text(device.name)
            }
        }
    }
}
