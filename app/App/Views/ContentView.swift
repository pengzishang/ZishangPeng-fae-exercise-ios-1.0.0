//
//  ContentView.swift
//  App
//
//  Created by Akos Polster on 11/06/2024.
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import SwiftUI
import SmartCaseKit

/// Application main view: List of discovered devices
struct ContentView: View {
    @Environment(SmartCaseDeviceManager.self) private var deviceManager
    @State private var selectedDevice: SmartCaseDevice?

    var body: some View {
        NavigationSplitView {
            List(deviceManager.devices, selection: $selectedDevice) { device in
                NavigationLink(value: device) {
                    DeviceRow(device: device)
                }
            }
            .navigationTitle("Smart Cases")
            .navigationSplitViewColumnWidth(300)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        deviceManager.enableDiscovery(true)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
        } detail: {
            if let device = selectedDevice {
                DeviceDetailView(device: device, selectedDevice: $selectedDevice)
            } else {
                ContentUnavailableView(
                    "Select a Smart Case",
                    systemImage: "airpodspro.chargingcase.wireless")
            }
        }
        .onAppear { deviceManager.enableDiscovery(true) }
        .onDisappear { deviceManager.enableDiscovery(false) }
        .onChange(of: selectedDevice) { oldValue, newValue in
            Log("\(String(describing: oldValue)) -> \(String(describing: newValue))")
            deviceManager.enableDiscovery(selectedDevice == nil)
            Task {
                await oldValue?.disconnect()
                try? await newValue?.connect()
            }
        }
    }
}
