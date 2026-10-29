//
//  DeviceDetailView.swift
//  App
//
//  Created by Akos Polster on 11/06/2024.
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import SwiftUI
import SVGView
import SmartCaseKit

/// Shows a device's details
struct DeviceDetailView: View {
    /// Device to display
    @Bindable var device: SmartCaseDevice
    /// Cleared to return to the "no device selected" state
    @Binding var selectedDevice: SmartCaseDevice?

    /// Fixed list of icons to cycle through when a button is clicked
    static let iconIndices: [UInt8] = Array(0 ..< 16)

    /// Fixed list of dark background colors to cycle through when a button is clicked,
    /// one for each icon in `buttonSVGs`
    static let backgroundColors: [(red: UInt8, green: UInt8, blue: UInt8)] = [
        (60, 20, 20),
        (20, 60, 20),
        (20, 20, 60),
        (60, 60, 20),
        (20, 60, 60),
        (60, 20, 60),
        (70, 40, 20),
        (40, 20, 70),
        (20, 70, 40),
        (70, 20, 40),
        (40, 70, 20),
        (20, 40, 70),
        (55, 35, 15),
        (15, 55, 35),
        (35, 15, 55),
        (55, 15, 35),
    ]

    static let buttonSVGs: [Data] = [
        try! Data(contentsOf: Bundle.main.url(forResource: "0", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "1", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "2", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "3", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "4", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "5", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "6", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "7", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "8", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "9", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "10", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "11", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "12", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "13", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "14", withExtension: "svg")!),
        try! Data(contentsOf: Bundle.main.url(forResource: "15", withExtension: "svg")!),
    ]

    var body: some View {
        VStack {
            Text("Name: \(device.name)\nConnected: \(device.isConnected ? "Yes" : "No"), \(device.buttons.count) buttons\n\nClick on a button to change its icon.")
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding()
                .navigationTitle("Smart Case Control")
            Button("Disconnect") {
                selectedDevice = nil
            }
            .disabled(!device.isConnected)
            Spacer()
                .frame(height: 30)
            HStack(spacing: 20) {
                ForEach(0 ..< device.buttons.count, id: \.self) { i in
                    let svg = Self.buttonSVGs[Int(device.buttons[i].imageIndex) % Self.buttonSVGs.count]
                    SVGView(data: svg)
                        .background(Color(
                            red: Double(device.buttons[i].backgroundRed) / 255.0,
                            green: Double(device.buttons[i].backgroundGreen) / 255.0,
                            blue: Double(device.buttons[i].backgroundBlue) / 255.0))
                        .cornerRadius(12)
                        .onTapGesture {
                            Log("Tap")
                            let button = device.buttons[i]
                            let iconPosition = Self.iconIndices.firstIndex(of: button.imageIndex) ?? -1
                            let nextImageIndex = Self.iconIndices[(iconPosition + 1) % Self.iconIndices.count]
                            let colorPosition = Self.backgroundColors.firstIndex {
                                $0.red == button.backgroundRed
                                    && $0.green == button.backgroundGreen
                                    && $0.blue == button.backgroundBlue
                            } ?? -1
                            let nextColor = Self.backgroundColors[(colorPosition + 1) % Self.backgroundColors.count]
                            Task {
                                try? await device.setButton(
                                    index: i,
                                    imageIndex: nextImageIndex,
                                    red: nextColor.red,
                                    green: nextColor.green,
                                    blue: nextColor.blue)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.orange, lineWidth: borderWidth(for: i))
                        )
                }
            }
            Spacer()
        }
        .padding()
    }

    func borderWidth(for buttonIndex: Int) -> CGFloat {
        guard
            let notification = device.lastNotification,
            notification.action == .buttonEvent,
            notification.payload.count >= 2
        else {
            return 0
        }
        return (notification.payload[0] == buttonIndex) ? 7 : 0
    }
}
