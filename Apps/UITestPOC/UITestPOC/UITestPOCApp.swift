//
//  UITestPOCApp.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 23/07/25.
//

import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
     
        return true
    }

    func applicationWillTerminate(_ application: UIApplication) {

    }

}

@main
struct UITestPOCApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
    var body: some Scene {
        WindowGroup {
         BaseView()
        }
    }
}


