//
//  ServerSSLPinningAppApp.swift
//  ServerSSLPinningApp
//
//  Created by Ashish Awasthi on 18/06/26.
//

import SwiftUI

@main
struct ServerSSLPinningAppApp: App {
    @StateObject private var pinStore = PinStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pinStore)
        }
    }
}
