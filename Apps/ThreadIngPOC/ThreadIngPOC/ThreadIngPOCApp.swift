//
//  ThreadIngPOCApp.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 16/09/24.
//

import SwiftUI

@main
struct ThreadIngPOCApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        SDKManager.shared.startSDK()
        return true
    }
}

