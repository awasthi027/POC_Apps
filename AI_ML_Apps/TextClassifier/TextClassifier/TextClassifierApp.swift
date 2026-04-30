//
//  TextClassifierApp.swift
//  TextClassifier
//
//  Created by Ashish Awasthi on 30/04/26.
//

import SwiftUI

@main
struct TextClassifierApp: App {

    var body: some Scene {
        
        WindowGroup {
            TabView {
                QAView()
                    .tabItem { Label("FAQ Bot", systemImage: "bubble.left.and.bubble.right") }
            }
        }
    }
}
