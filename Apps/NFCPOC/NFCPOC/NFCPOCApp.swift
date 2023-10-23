//
//  NFCPOCApp.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 16/10/23.
//

import SwiftUI

@main
struct NFCPOCApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State var rootView: RootScreen = .scanTag

    var body: some Scene {
        WindowGroup {
            switch self.rootView {
            case .scanTag:
                NavHandler {
                    NFCScannerView()
                        .environment(\.currentRootView, self.$rootView)
                }
            case .details(let nFCNDEFMessage):
                NavHandler {
                    NFCTagDetailsView(message: nFCNDEFMessage)
                        .environment(\.currentRootView, self.$rootView)
                }

            }
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        if ProcessInfo.processInfo.arguments.contains("isRunningUITests") {
            // Prepare application for UI tests.
            print("UI Test are running....")
        }
        return true
    }
    
    /// This method will call when user press in control panel NFC tag
    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else {
            return false
        }

        // Confirm that the NSUserActivity object contains a valid NDEF message.
        let ndefMessage = userActivity.ndefMessagePayload
        guard !ndefMessage.records.isEmpty,
            ndefMessage.records[0].typeNameFormat != .empty else {
                return false
        }
        
        return true
    }
}

