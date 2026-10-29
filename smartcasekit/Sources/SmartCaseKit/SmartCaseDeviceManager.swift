//
//  SmartCaseDeviceManager.swift
//  SmartCaseKit
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import CoreBluetooth
import Observation

/// Discovers and tracks smart case devices over BLE
@Observable public class SmartCaseDeviceManager: NSObject, CBCentralManagerDelegate {
    /// Discovered/connected smart case devices
    public var devices: [SmartCaseDevice] = []

    override public init() {
        self.manager = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        manager.delegate = self
    }

    /// Start/stop device discovery
    public func enableDiscovery(_ enable: Bool) {
        Log(enable)
        shouldScan = enable
        if enable {
            startDiscovery()
        } else {
            stopDiscovery()
        }
    }

    // MARK: - CBCentralManagerDelegate

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Log(central.state.friendlyName)
        if shouldScan {
            startDiscovery()
        }
    }

    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let device = createDevice(from: peripheral, advertisementData: advertisementData) {
            appendToDeviceList(device: device)
        }
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Log()
        getDevice(for: peripheral)?.peripheralDidConnect()
    }

    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        if let error {
            LogError(error)
        } else {
            Log()
        }
        getDevice(for: peripheral)?.peripheralDidFailToConnect(error: error)
    }

    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?) {
        if let error {
            LogError(error)
        } else {
            Log()
        }
        getDevice(for: peripheral)?.peripheralDidDisconnect()
    }

    // MARK: - Internal

    private let manager: CBCentralManager
    private var shouldScan = false

    private func startDiscovery() {
        Log()
        devices = []
        guard manager.state == .poweredOn else { return }
        manager.scanForPeripherals(withServices: [SmartCaseProtocol.serviceUUID])
    }

    private func stopDiscovery() {
        Log()
    }

    /// Append a device to the discovered devices, trigger observers
    private func appendToDeviceList(device: SmartCaseDevice) {
        var updatedDevices = self.devices
        guard !updatedDevices.contains(where: { $0.id == device.id }) else { return }
        Log(device)
        updatedDevices.append(device)
        self.devices = updatedDevices.orderedByName
    }

    /// Create a smart case device corresponding to a CBPeripheral
    private func createDevice(from peripheral: CBPeripheral, advertisementData: [String: Any]) -> SmartCaseDevice? {
        guard let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) else {
            return nil
        }
        let device = SmartCaseDevice(manager: self.manager, peripheral: peripheral)
        device.name = name
        return device
    }

    /// Get the already discovered device corresponding to the given peripheral
    private func getDevice(for peripheral: CBPeripheral) -> SmartCaseDevice? {
        for device in devices {
            if device.peripheral == peripheral {
                Log("\(peripheral) -> \(device)")
                return device
            }
        }
        Log("\(peripheral) -> no device")
        return nil
    }
}

extension [SmartCaseDevice] {
    var orderedByName: [SmartCaseDevice] {
        self.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}

extension CBManagerState {
    var friendlyName: String {
        switch self {
        case .poweredOn: "Powered on"
        case .poweredOff: "Powered off"
        case .resetting: "Resetting"
        case .unauthorized: "Unauthorized"
        case .unknown: "Unknown"
        case .unsupported: "Unsupported"
        @unknown default: "Unknown (\(self.rawValue))"
        }
    }
}
