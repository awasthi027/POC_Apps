//
//  ContentView.swift
//  BLE
//
//  Created by Ashish Awasthi on 29/08/25.
//

import SwiftUI
import BLEDevice

struct ContentView: View {
    // On Peripheral Device
 //   @ObservedObject var service = PeripheralServerService()
    @State private var chatText: String = ""

    var body: some View {
        VStack(spacing: 10) {
//            Text("Peripheral State: \(service.bleState.state)")
//                .padding()
//            self.peripheralStatusView()
//            self.testingCharacticsView()
//
//            Text("Response:\n\(service.readDataSendByClient)")
//                .padding()
//            self.sendMessageView()
            Button {
              //  self.service.readDataSendByClient = ""
            } label: {
                NavigationLink(value: ControllerNavigation.chatView) {
                    Text("Start Chat")
                }
            }
        }
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
       return HStack(spacing: 10) {
            Button {
//                service.stopAdvertising()
            } label: {
                Text("Stop Advertising")
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)

            Button {
//                self.service.startAdvertising()
            } label: {
                Text("Start Advertising")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
        }
    }
    func testingCharacticsView() -> some View {
       return HStack(spacing: 10) {
            Button {
//                self.service.sendValueTotCharacteristic(characteristic: .first,
//                                                        data: "First Characteristic Notification".data)
            } label: {
                Text("1st Notify" )
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)

            Button {
//                self.service.sendValueTotCharacteristic(characteristic: .second,
//                                                        data: "Second Characteristic Notification".data)
            } label: {
                Text("2nd Notify")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)

            Button {
                var byteDictionary: [String: UInt8] = [:]
                for i in 0..<10 {
                    byteDictionary["key\(i)"] = UInt8(i)
                }
                let dataToSend = byteDictionary.toJSONData ?? Data()
                print("Number of bytes to send: \(dataToSend.count)")
//                self.service.sendValueTotCharacteristic(characteristic: .json,
//                                                        data: dataToSend)
            } label: {
                Text("Notify Json")
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
                    // self.service.readDataSendByClient = ""
                 } label: {
                     Text("Clear Message")
                         .font(.headline)
                 }
                 .buttonStyle(.borderedProminent)
                 .buttonBorderShape(.capsule)
                 .controlSize(.large)
                 Button {
//                     self.service.sendValueTotCharacteristic(characteristic: .oneToOneChat,
//                                                             data: chatText.data)
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
