//
//  AshiTunnelAppApp.swift
//  AshiTunnelApp
//
//  Created by Ashish Awasthi on 06/05/26.
//

import SwiftUI

@main
struct AshiTunnelAppApp: App {
    @StateObject private var gatekeeper = URLGatekeeper()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gatekeeper)
                .onOpenURL { incomingURL in
                    gatekeeper.handleIncomingURL(incomingURL)
                }
        }
    }
}
