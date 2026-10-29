//
//  SmartCasePeripheral.swift
//  SmartCase
//
//  Created by Akos Polster on 10/06/2024.
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import CoreBluetooth

@Observable class SmartCasePeripheral: NSObject, CBPeripheralManagerDelegate {
    static var shared = SmartCasePeripheral()
    var requestHandler: ((SmartCaseMessage) -> SmartCaseMessage?)?

    override init() {
        self.smartCaseCharacteristic = CBMutableCharacteristic(
            type: Self.smartCaseCharacteristicCBUUID, properties: [.notify, .write, .writeWithoutResponse, .read],
            value: nil,
            permissions: [.readable, .writeable]
        )
        self.smartCaseService = CBMutableService(type: Self.smartCaseServiceCBUUID, primary: true)
        self.smartCaseService.characteristics = [self.smartCaseCharacteristic]
        super.init()
        peripheralManager.delegate = self
    }

    func sendMessage(_ message: SmartCaseMessage) {
        Log(message.data.hexEncoded.truncated(to: 64))
        peripheralManager.updateValue(message.data, for: smartCaseCharacteristic, onSubscribedCentrals: nil)
    }

    // MARK: - CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        Log("\(peripheral.state)")
        if peripheral.state == .poweredOn {
            addSmartCaseService()
            startAdvertising()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        if let error = error {
            LogError("Service \(service.uuid): \(error)")
            return
        }
        Log("Service \(service.uuid)")
        let characteristicIDs = (service.characteristics ?? []).map { $0.uuid }
        Log("Characteristics: \(characteristicIDs)")
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        if let error = error {
            LogError(error)
        } else {
            Log()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        Log()
        for request in requests {
            handleWriteRequest(peripheral: peripheral, request: request)
        }
    }

    // MARK: - Internal

    @ObservationIgnored private var peripheralManager = CBPeripheralManager(delegate: nil, queue: nil)
    private static let smartCaseCharacteristicCBUUID = CBUUID(nsuuid: UUID(uuidString: "1CA28021-E4F7-4F05-B833-0DB9A7B1DC86")!)
    private static let smartCaseServiceCBUUID = CBUUID(nsuuid: UUID(uuidString: "E2FEBAD9-CEED-4FD7-A066-DD91AFAA09F7")!)

    private let smartCaseCharacteristic: CBMutableCharacteristic
    private let smartCaseService: CBMutableService

    private func addSmartCaseService() {
        Log()
        peripheralManager.add(smartCaseService)
    }

    private func startAdvertising() {
        Log()
        peripheralManager.startAdvertising(
            [
                CBAdvertisementDataLocalNameKey: "Bragi Smart Case",
                CBAdvertisementDataServiceUUIDsKey: [Self.smartCaseServiceCBUUID]
            ]
        )
    }

    private func handleWriteRequest(peripheral: CBPeripheralManager, request: CBATTRequest) {
        Log()
        guard
            request.characteristic.service?.uuid == Self.smartCaseServiceCBUUID,
            request.characteristic.uuid == Self.smartCaseCharacteristicCBUUID
        else {
            LogError("Unknown characteristic \(request.characteristic)")
            return
        }
        guard let data = request.value else {
            LogError("No data in request")
            return
        }
        guard let smartCaseRequest = SmartCaseMessage(data: data) else {
            LogError("Request is not a SmartCaseMessage: \(data.hexEncoded)")
            return
        }
        if let response = requestHandler?(smartCaseRequest) {
            writeResponse(peripheral: peripheral, request: request, message: response)
        } else if smartCaseRequest.type == .request {
            let smartCaseResponse = SmartCaseMessage(
                id: smartCaseRequest.id,
                type: SmartCaseMessageType.response,
                action: smartCaseRequest.action,
                payload: Data([1]))
            writeResponse(peripheral: peripheral, request: request, message: smartCaseResponse)
        }
    }

    private func writeResponse(peripheral: CBPeripheralManager, request: CBATTRequest, message: SmartCaseMessage) {
        Log()
        peripheral.respond(to: request, withResult: .success)
        let didSendValue = peripheral.updateValue(message.data, for: smartCaseCharacteristic, onSubscribedCentrals: nil)
        if !didSendValue {
            LogError("Failed to update characteristic's value ")
        }
    }
}
