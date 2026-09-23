//
//  PiPLearningApp.swift
//  PiPLearning
//
//  Created by Ashish Awasthi on 22/09/26.
//

import SwiftUI
import AVFoundation

@main
struct PiPLearningApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    static var shared: AppDelegate?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppDelegate.shared = self
        configureAudioSession()
        return true
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // This is called when app enters background
        // SwiftUI ScenePhase will handle the PiP activation
        print("App entered background")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        print("App will enter foreground")
    }
    
    private func configureAudioSession() {
        // Configure audio session on background thread to avoid UI unresponsiveness
        DispatchQueue.global(qos: .default).async {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                // Use .playback category for audio/video playback
                // .duckOthers - reduce other audio when this plays
                try audioSession.setCategory(.playback, mode: .default, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                print("Audio session configured successfully")
            } catch {
                print("Audio session configuration error: \(error)")
            }
        }
    }
}
