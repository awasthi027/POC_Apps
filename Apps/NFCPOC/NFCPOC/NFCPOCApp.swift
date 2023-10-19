//
//  NFCPOCApp.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 16/10/23.
//

import SwiftUI

@main
struct NFCPOCApp: App {
    var body: some Scene {
        WindowGroup {
            NavHandler {
                ContentView()
            }
        }
    }
}

struct NavHandler<Content>: View where Content: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack(root: content)
        } else {
            NavigationView(content: content)
        }
    }
}
