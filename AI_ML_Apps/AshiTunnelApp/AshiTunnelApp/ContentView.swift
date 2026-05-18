//
//  ContentView.swift
//  AshiTunnelApp
//
//  Created by Ashish Awasthi on 06/05/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var gatekeeper: URLGatekeeper

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "link.badge.plus")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("URL Gatekeeper")
                .font(.title3)
                .fontWeight(.semibold)
            Text(gatekeeper.statusMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .alert("Open this URL in Safari?", isPresented: $gatekeeper.isPromptVisible) {
            Button("Deny", role: .destructive) {
                gatekeeper.denyPendingURL()
            }
            Button("Approve") {
                gatekeeper.approvePendingURL()
            }
        } message: {
            Text(gatekeeper.pendingURL?.absoluteString ?? "Unknown URL")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(URLGatekeeper())
}
