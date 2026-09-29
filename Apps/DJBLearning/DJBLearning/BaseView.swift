//
//  ContentView.swift
//  DJBLearning
//
//  Root UI: two independent, side-by-side jailbreak verification paths.
//   - "Native Rules" -> hardcoded native Swift checks (JailbreakDetector).
//   - "JS Rules"     -> dynamic rules executed from decoded_payload.js via
//                       JavaScriptCore (see JSEngine/).
//  The two tabs share no code/state so they can be compared directly.
//

import SwiftUI

struct BaseView: View {
    var body: some View {
        TabView {
            NativeRulesView()
                .tabItem {
                    Label("Native Rules", systemImage: "cpu")
                }

            JSRulesView()
                .tabItem {
                    Label("JS Rules", systemImage: "curlybraces")
                }
        }
    }
}

#Preview {
    BaseView()
}
