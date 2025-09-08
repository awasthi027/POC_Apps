//
//  ContentView.swift
//  BLEClient
//
//  Created by Ashish Awasthi on 29/08/25.
//

import SwiftUI
import BLEDevice

struct ContentView: View {
 @State private var chatText: String = ""
 //@ObservedObject var service = CentralClientService()

    var body: some View {
        VStack(spacing: 10) {
//            Text("Peripheral Name: \(service.peripheralName)\nBLE State: \(self.service.isBLEConnected == true ? "Connected" : "Disconnected")")
//                .font(.footnote)
//            peripheralStatusView()
//            testingCharacticsView()
//            Text("Response:\n\(self.service.dataReceived)")
//                .font(.footnote)
//            sendMessageView()
            Button {
//                self.service.dataReceived = ""
            } label: {
                NavigationLink(value: ControllerNavigation.chatView) {
                    Text("Start Chat")
                }
            }
        }
        .padding()
        .navigationDestination(for: ControllerNavigation.self) { item in
            switch item {
            case .chatView:
                ChatView()
            }
        }
        .navigationBarTitle("Home", displayMode: .inline)
        .navigationViewStyle(.automatic)
    }
}

extension ContentView {

    func peripheralStatusView () -> some View {
        HStack(spacing: 10) {
            Button {
//                self.service.disconnect()
            } label: {
                Text("Disconnect PeriPheral")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            Button {
//                self.service.startScanning()
            } label: {
                Text("Start Scanning")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
    }
    func testingCharacticsView() -> some View {

        return HStack(spacing: 10)  {
            Button {
//                self.service.sendMessage(characteristic: .first,
//                                         data: "Hello First Characteristic".data)
            } label: {
                Text("1st Msg")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)

            Button {
//                self.service.sendMessage(characteristic: .second,
//                                         data: "Hello Second Characteristic".data)
            } label: {
                Text("2nd Msg")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)

            Button {
                let sampleDict: [String: Int] = [
                    "a": 1,
                    "b": 2,
                    "c": 3,
                    "d": 4,
                    "e": 5
                ]
//                self.service.sendMessage(characteristic: .json,
//                                         data: sampleDict.toJSONData ?? Data())
            } label: {
                Text("JSON Msg")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
    }

    func sendMessageView() -> some View {
        return VStack {
            TextField("Type something", text: self.$chatText)
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)
            HStack {
                Button {
//                    self.service.dataReceived = ""
                } label: {
                    Text("Clear Message")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                Button {
//                    self.service.sendMessage(characteristic: .oneToOneChat,
//                                             data: self.chatText.data)
                    self.chatText = ""
                } label: {
                    Text("Send Message")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
        }
    }
}

#Preview {
    ContentView()
}
