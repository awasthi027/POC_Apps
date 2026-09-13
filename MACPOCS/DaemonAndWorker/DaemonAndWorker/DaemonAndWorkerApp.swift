//
//  DaemonAndWorkerApp.swift
//  DaemonAndWorker
//
//  Created by Ashish Awasthi on 27/08/26.
//

import SwiftUI

@main
struct DaemonAndWorkerApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem { Label("Daemon", systemImage: "server.rack") }
                WorkerDemoView()
                    .tabItem { Label("Worker", systemImage: "gearshape.2") }
            }
        }
    }
}
