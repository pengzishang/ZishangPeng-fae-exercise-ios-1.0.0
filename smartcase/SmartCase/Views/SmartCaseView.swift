//
//  SmartCaseView.swift
//  SmartCase
//
//  Created by Akos Polster on 10/06/2024.
//  Copyright (c) Bragi GmbH. All rights reserved.
//

import SwiftUI
import SVGView

struct SmartCaseView: View {
    @Environment(SmartCase.self) var smartCase

    private static let buttonSVGs: [Data] = [
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
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                Text("\nBragi Smart Case\n")
                    .multilineTextAlignment(.center)
                    .font(.title)
                    .foregroundColor(.white)
                HStack(spacing: 20) {
                    ForEach(0 ..< smartCase.buttons.count, id: \.self) { i in
                        let button = smartCase.buttons[i]
                        let svg = Self.buttonSVGs[Int(button.imageIndex) % Self.buttonSVGs.count]
                        SVGView(data: svg)
                            .background(Color(
                                red: Double(button.backgroundRed) / 255.0,
                                green: Double(button.backgroundGreen) / 255.0,
                                blue: Double(button.backgroundBlue) / 255.0))
                            .cornerRadius(12)
                            .frame(maxHeight: 200)
                            .onTapGesture {
                                smartCase.sendButtonEvent(buttonIndex: i, event: 0)
                            }
                    }
                }
            }
            .padding()
        }
    }
}
