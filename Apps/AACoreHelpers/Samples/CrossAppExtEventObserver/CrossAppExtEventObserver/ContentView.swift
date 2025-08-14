//
//  ContentView.swift
//  CrossAppExtEventObserver
//
//  Created by Ashish Awasthi on 05/06/25.
//

import SwiftUI
import CoreHelpers


struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear() {
            CrossAppEventHandler.shared.send("SessionUpdate")
        }
    }
}

#Preview {
    ContentView()
}
