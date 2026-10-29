//
//  SmartCaseDevice.swift
//  SmartCaseKit
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import CoreBluetooth
import Observation
import SwiftUI

/// A discovered smart case device
@Observable public class SmartCaseDevice: NSObject, Identifiable, CBPeripheralDelegate {
    @ObservationIgnored public var id: UUID { peripheral.identifier }
    public var name: String = ""
    override public var description: String { "SmartCaseDevice(id: \(id), name: '\(name)')" }
    public var image = AnyView(Image(systemName: "airpodspro.chargingcase.wireless").symbolRenderingMode(.palette).foregroundStyle(.secondary))
    public var isConnected = false
    public var buttons: [SmartCaseButton] = []
    public var lastNotification: SmartCaseMessage?
    @ObservationIgnored let peripheral: CBPeripheral

    init(manager: CBCentralManager, peripheral: CBPeripheral) {
        self.manager = manager
        self.peripheral = peripheral
        super.init()
    }

    /// Connect the corresponding CBPeripheral, and discover its services and characteristics.
    /// Returns once the device is ready for requests, or throws if connecting fails.
    public func connect() async throws {
        Log()
        guard let manager else { throw SmartCaseError.notConnected }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connectContinuation = continuation
            manager.connect(peripheral)
        }
    }

    /// Disconnect from the corresponding CBPeripheral. Returns once disconnected.
    public func disconnect() async {
        Log()
        guard isConnected, let manager else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            disconnectContinuation = continuation
            manager.cancelPeripheralConnection(peripheral)
        }
    }

    /// Get smart case buttons, update `buttons`, and return the new value
    @discardableResult
    public func updateButtons() async throws -> [SmartCaseButton] {
        Log()
        let request = SmartCaseMessage(type: .request, action: .getButtons)
        let response = try await sendRequest(request)
        guard response.payload.count > 1 else {
            LogError("Invalid response: \(response)")
            throw SmartCaseError.invalidResponse
        }
        var buttons: [SmartCaseButton] = []
        let buttonCount = Int(response.payload[1])
        for buttonIndex in (0 ..< buttonCount) {
            let imageIndex = response.payload[2 + buttonIndex * 4 + 1]
            let red = response.payload[2 + buttonIndex * 4 + 1]
            let green = response.payload[2 + buttonIndex * 4 + 2]
            let blue = response.payload[2 + buttonIndex * 4 + 3]
            Log("\(buttonIndex): Image \(imageIndex), red \(red), green \(green), blue \(blue)")
            buttons.append(SmartCaseButton(
                imageIndex: imageIndex,
                backgroundRed: red,
                backgroundGreen: green,
                backgroundBlue: blue))
        }
        self.buttons = buttons
        return buttons
    }

    /// Set the given button's image index
    public func setButtonImage(index: Int, imageIndex: UInt8) async throws {
        Log()
        let payload = Data([UInt8(index), imageIndex])
        let request = SmartCaseMessage(type: .request, action: .setButtonImage, payload: payload)
        let response = try await sendRequest(request)
        Log(response)
        let newButtons = buttons
        newButtons[index].imageIndex = imageIndex
        buttons = newButtons
    }

    /// Set the given button's background color and image index
    public func setButton(index: Int, imageIndex: UInt8, red: UInt8, green: UInt8, blue: UInt8) async throws {
        Log()
        let payload = Data([UInt8(index), red, green, blue])
        let request = SmartCaseMessage(type: .request, action: .setButtonBackground, payload: payload)
        let response = try await sendRequest(request)
        Log(response)
        let newButtons = buttons
        newButtons[index].backgroundRed = red
        newButtons[index].backgroundGreen = green
        newButtons[index].backgroundBlue = blue
        buttons = newButtons
        try await setButtonImage(index: index, imageIndex: imageIndex)
    }

    // MARK: - CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        if let error {
            LogError(error)
            failConnect(with: error)
            return
        }
        guard let services = peripheral.services else {
            LogError("No services")
            failConnect(with: SmartCaseError.invalidResponse)
            return
        }
        Log(services.map { $0.uuid })
        guard let service = services.first(where: { $0.uuid == SmartCaseProtocol.serviceUUID }) else {
            LogError("SmartCase service not found")
            failConnect(with: SmartCaseError.invalidResponse)
            return
        }
        Log("Found SmartCase service")
        peripheral.discoverCharacteristics([SmartCaseProtocol.characteristicUUID], for: service)
    }

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?) {
        if let error {
            LogError(error)
            failConnect(with: error)
            return
        }
        guard service.uuid == SmartCaseProtocol.serviceUUID else {
            return
        }
        guard let characteristics = service.characteristics else {
            LogError("No characteristics")
            failConnect(with: SmartCaseError.invalidResponse)
            return
        }
        Log(characteristics.map { $0.uuid })
        guard let characteristic = characteristics.first(where: { $0.uuid == SmartCaseProtocol.characteristicUUID }) else {
            LogError("SmartCase characteristic not found")
            failConnect(with: SmartCaseError.invalidResponse)
            return
        }
        Log("Found SmartCase characteristic")
        self.smartCaseCharacteristic = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
        isConnected = true
        Task {
            try? await updateButtons()
        }
        connectContinuation?.resume()
        connectContinuation = nil
    }

    public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?) {
        guard characteristic.uuid == SmartCaseProtocol.characteristicUUID else {
            return
        }
        if let error {
            LogError(error)
            return
        }
        guard let data = characteristic.value else {
            LogError("Nothing to read")
            return
        }
        guard let message = SmartCaseMessage(data: data) else {
            LogError("Not a SmartCaseMessage: \(data.hexEncoded)")
            return
        }
        switch message.type {
        case .notification:
            Log("Notification: \(message)")
            self.lastNotification = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.lastNotification = nil
            }
        case .response:
            Log("Response: \(message)")
            guard let responseHandler = pendingRequests[message.id] else {
                LogError("No response handler for request ID \(message.id)")
                return
            }
            pendingRequests.removeValue(forKey: message.id)
            responseHandler(.success(message))
        case .request:
            LogError("Unexpected request \(message)")
        }
    }

    // MARK: - Internal

    private weak var manager: CBCentralManager?
    private var pendingRequests: [UInt16: (Result<SmartCaseMessage, Error>) -> Void] = [:]
    private var smartCaseCharacteristic: CBCharacteristic?
    private var connectContinuation: CheckedContinuation<Void, Error>?
    private var disconnectContinuation: CheckedContinuation<Void, Never>?

    /// Send a request, return the response
    private func sendRequest(_ request: SmartCaseMessage) async throws -> SmartCaseMessage {
        Log(request)
        guard let smartCaseCharacteristic else {
            LogError("No SmartCase characteristic")
            throw SmartCaseError.notConnected
        }
        let data = request.data
        let maximumLength = peripheral.maximumWriteValueLength(for: .withoutResponse)
        guard data.count < maximumLength else {
            LogError("Request too long: \(data.count) > \(maximumLength)")
            throw SmartCaseError.requestTooLong
        }
        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[request.id] = { result in
                continuation.resume(with: result)
            }
            peripheral.writeValue(data, for: smartCaseCharacteristic, type: .withoutResponse)
        }
    }

    private func failConnect(with error: Error) {
        connectContinuation?.resume(throwing: error)
        connectContinuation = nil
    }

    /// Called by the device manager after the underlying CBPeripheral has connected
    func peripheralDidConnect() {
        Log()
        peripheral.delegate = self
        peripheral.discoverServices([SmartCaseProtocol.serviceUUID])
    }

    /// Called by the device manager if connecting to the underlying CBPeripheral failed
    func peripheralDidFailToConnect(error: Error?) {
        Log()
        failConnect(with: error ?? SmartCaseError.notConnected)
    }

    /// Called by the device manager after the underlying CBPeripheral has disconnected
    func peripheralDidDisconnect() {
        Log()
        isConnected = false
        disconnectContinuation?.resume()
        disconnectContinuation = nil
    }
}
