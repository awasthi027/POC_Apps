//
//  DJBLearningApp.swift
//  DJBLearning
//
//  Created by Ashish Awasthi on 28/09/26.
//

import SwiftUI

@main
struct DJBLearningApp: App {
    
    init() {
        JailbreakDetector.shared.register(StandardJailbreakChecks.all)
    }
    
    var body: some Scene {
        WindowGroup {
            BaseView()
        }
    }
}
