//
//  SmartCase.swift
//  SmartCase
//
//  Created by Akos Polster on 10/06/2024.
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import Foundation
import SwiftUI

/// Models a smart case with four SVG buttons
@Observable class SmartCase: Identifiable {
    static var shared = SmartCase()

    var id: String = UUID().uuidString
    var name: String = ""
    weak var peripheral: SmartCasePeripheral? {
        didSet {
            peripheral?.requestHandler = handleRequest
        }
    }

    var buttons: [SmartCaseButton] = [] {
        didSet {
            storeButtons()
        }
    }

    init() {
        loadButtons()
    }

    /// Send a .buttonEvent notification
    func sendButtonEvent(buttonIndex: Int, event: UInt8) {
        Log("Button \(buttonIndex), event \(event)")
        let payload = Data([UInt8(buttonIndex), event])
        let event = SmartCaseMessage(type: .notification, action: .buttonEvent, payload: payload)
        peripheral?.sendMessage(event)
    }

    // MARK: - Internal

    @ObservationIgnored
    @Persistent(key: "buttons", defaultValue: [
        SmartCaseButton(),
        SmartCaseButton(),
        SmartCaseButton(),
        SmartCaseButton()
    ])
    private var persistentButtons: [SmartCaseButton]

    private func loadButtons() {
        buttons = persistentButtons
    }

    private func storeButtons() {
        persistentButtons = buttons
    }

    private func handleRequest(_ request: SmartCaseMessage) -> SmartCaseMessage? {
        Log(request)
        switch request.action {
        case .getButtons:
            Log("getButtons")
            var payload = Data([0, UInt8(buttons.count)]) // OK, n buttons
            for button in buttons {
                payload.append(Data([button.imageIndex, button.backgroundRed, button.backgroundGreen, button.backgroundBlue]))
            }
            return SmartCaseMessage(id: request.id, type: .response, action: .getButtons, payload: payload)

        case .setButtonImage:
            guard request.payload.count >= 2 else {
                LogError("setButtonImage: Payload too short")
                return createResponse(for: request, success: false)
            }
            let button = Int(request.payload[0])
            let imageIndex = request.payload[1]
            if button > buttons.count - 1 {
                LogError("setButtonImage: Invalid button index \(button)")
                return createResponse(for: request, success: false)
            }
            Log("setButtonImage, button \(button), image index \(imageIndex)")
            var newButtons = self.buttons
            newButtons[button] = SmartCaseButton(
                imageIndex: imageIndex,
                backgroundRed: buttons[button].backgroundRed,
                backgroundGreen: buttons[button].backgroundGreen,
                backgroundBlue: buttons[button].backgroundBlue
            )
            self.buttons = newButtons

        case .setButtonBackground:
            guard request.payload.count == 4 else {
                LogError("setButtonBackground: Invalid payload")
                return createResponse(for: request, success: false)
            }
            let button = Int(request.payload[0])
            if button > buttons.count - 1 {
                LogError("setButtonBackground: Invalid button index \(button)")
                return createResponse(for: request, success: false)
            }
            let red = request.payload[1]
            let green = request.payload[1]
            let blue = request.payload[3]
            var newButtons = self.buttons
            newButtons[button] = SmartCaseButton(
                imageIndex: self.buttons[button].imageIndex,
                backgroundRed: red,
                backgroundGreen: green,
                backgroundBlue: blue
            )
            self.buttons = newButtons

        default:
            LogError("Unknown request")
            return createResponse(for: request, success: false)
        }

        return createResponse(for: request, success: true)
    }

    private func createResponse(for request: SmartCaseMessage, success: Bool) -> SmartCaseMessage {
        let successByte: UInt8 = success ? 0 : 1
        return SmartCaseMessage(id: request.id, type: .response, action: request.action, payload: Data([successByte]))
    }
}
