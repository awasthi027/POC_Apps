//
//  AACoreHelperSampleAppApp.swift
//  AACoreHelperSampleApp
//
//  Created by Ashish Awasthi on 06/03/25.
//

import SwiftUI
import CoreHelpers

@main
struct AACoreHelperSampleAppApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
}

