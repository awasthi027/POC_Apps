//
//  LaunchTimeView.swift
//  DebugLearning
//
//  Displays the launch-phase durations recorded by LaunchTimeTracker so you
//  can see, right inside the app, which phase of launch was slow.
//

import SwiftUI

struct LaunchTimeView: View {
    var body: some View {
        List {
            Section {
                ForEach(Array(LaunchTimeTracker.recordedPhases.enumerated()), id: \.offset) { _, phase in
                    HStack {
                        Text(phase.name)
                        Spacer()
                        Text(String(format: "%.1f ms", phase.seconds * 1000))
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            } header: {
                Text("Recorded this launch")
            } footer: {
                Text("""
                For deeper analysis:
                • Console.app → filter subsystem "DebugLearning", category "LaunchTime"
                • Instruments → Product ▸ Profile → "App Launch" template, look at the \
                os_signpost track for these same phases next to Apple's pre-main/main/first-frame markers
                • Scheme ▸ Run ▸ Arguments ▸ Environment Variables → DYLD_PRINT_STATISTICS = 1 \
                to see dylib load / rebase / bind / ObjC setup time (pre-main), printed to console before app code runs
                """)
            }
        }
        .navigationTitle("Launch Time")
    }
}

#Preview {
    NavigationStack {
        LaunchTimeView()
    }
}
