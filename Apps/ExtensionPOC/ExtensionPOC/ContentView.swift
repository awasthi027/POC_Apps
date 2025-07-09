//
//  ContentView.swift
//  ExtensionPOC
//
//  Created by Ashish Awasthi on 29/06/25.
//

import SwiftUI
import LearningSubspecSDK
import os.log


struct ContentView: View {
    // Create a custom log object
    let log = OSLog(
        subsystem: "ashi.com.com.ExtensionPOC",
        category: "ExtensionPOCApp"
    )

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .onAppear() {
            os_log("Default Type Log Print in MAC Console", log: log, type: .default)
            os_log("Fault Type Log Print in MAC Console", log: log, type: .fault)
            os_log("Error Type Log Print in MAC Console", log: log, type: .error)
            os_log("Info Type Log Print in MAC Console", log: log, type: .info)
        }
    }
}

#Preview {
    ContentView()
}
