//
//  SmartCaseMessageTests.swift
//  SmartCaseKitTests
//
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import Testing
import Foundation
@testable import SmartCaseKit

@Test func messageRoundTrip() {
    let original = SmartCaseMessage(id: 42, type: .request, action: .setButtonBackground, payload: Data([0, 10, 20, 30]))
    let decoded = SmartCaseMessage(data: original.data)
    #expect(decoded?.id == 42)
    #expect(decoded?.type == .request)
    #expect(decoded?.action == .setButtonBackground)
    #expect(decoded?.payload == Data([0, 10, 20, 30]))
}

@Test func messageTooShortIsRejected() {
    #expect(SmartCaseMessage(data: Data([0, 1])) == nil)
}
