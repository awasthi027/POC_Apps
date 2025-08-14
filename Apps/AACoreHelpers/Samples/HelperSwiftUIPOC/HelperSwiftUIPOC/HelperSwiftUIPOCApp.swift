//
//  HelperSwiftUIPOCApp.swift
//  HelperSwiftUIPOC
//
//  Created by Ashish Awasthi on 12/08/25.
//

import SwiftUI

@main
struct HelperSwiftUIPOCApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

import CoreHelpers
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions
                     launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        CoreHelperManager.shared.config(writingToolsAllowed: false,
                                         copyPasteOutsideAllowed: true,
                                         pasteInSideAllowed: true)
        return true
    }
}
