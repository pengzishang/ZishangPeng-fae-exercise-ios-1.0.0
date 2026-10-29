//
//  SmartCaseProtocol.swift
//  SmartCaseKit
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import CoreBluetooth

/// BLE service/characteristic identifiers for the Simple Bragi Smart Case (SBSC) protocol
public enum SmartCaseProtocol {
    public static let serviceUUID = CBUUID(string: "E2FEBAD9-CEED-4FD7-A066-DD91AFAA09F7")
    public static let characteristicUUID = CBUUID(string: "1CA28021-E4F7-4F05-B833-0DB9A7B1DC86")
}
