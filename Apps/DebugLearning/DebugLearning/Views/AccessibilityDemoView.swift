//
//  AccessibilityDemoView.swift
//  DebugLearning
//
//  Demonstrates "Accessibility and device-state checks": catching truncated
//  text and mirrored-layout bugs by previewing with large Dynamic Type,
//  right-to-left layout direction, and dark mode — *before* a customer
//  reports "text is cut off" or "it looks broken".
//

import SwiftUI

struct AccessibilityDemoView: View {
    @State private var showFixedVersion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Picker("Version", selection: $showFixedVersion) {
                Text("🐞 Buggy").tag(false)
                Text("✅ Fixed").tag(true)
            }
            .pickerStyle(.segmented)

            if showFixedVersion {
                FixedNotificationRow()
            } else {
                BuggyNotificationRow()
            }

            if ProcessInfo.processInfo.isLowPowerModeEnabled {
                Label("Low Power Mode is ON — animations should be reduced", systemImage: "battery.25")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            Text("Tip: switch Dynamic Type size in Settings, or use the previews below in Xcode canvas.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("Accessibility Checks")
    }
}

/// ISSUE: `lineLimit(1)` + a hard-coded fixed `frame(width:)` causes the label
/// to truncate as soon as Dynamic Type grows past the default size — and the
/// fixed width doesn't adapt when the system switches to a right-to-left
/// language, so spacing looks wrong/mirrored incorrectly.
private struct BuggyNotificationRow: View {
    var body: some View {
        HStack {
            Image(systemName: "bell.fill")
            Text("You have 3 new notifications waiting for your review")
                .lineLimit(1)
                .frame(width: 220, alignment: .leading)
        }
        .padding()
        .background(.red.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// FIX: remove the fixed width, allow the text to wrap across multiple lines
/// (`lineLimit(nil)` + `fixedSize(horizontal: false, vertical: true)`), and
/// let `HStack` handle RTL mirroring automatically instead of forcing a width.
private struct FixedNotificationRow: View {
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "bell.fill")
            Text("You have 3 new notifications waiting for your review")
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .background(.green.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Previews exercising device-state checks

//#Preview("Default") {
//    NavigationStack {
//        AccessibilityDemoView()
//    }
//}

//#Preview("Accessibility XXXL + RTL — reveals truncation & mirroring bugs") {
//    NavigationStack {
//        AccessibilityDemoView()
//    }
//    .environment(\.dynamicTypeSize, .accessibility5)
//    .environment(\.layoutDirection, .rightToLeft)
//}

#Preview("Accessibility XXXL only") {
    NavigationStack {
        AccessibilityDemoView()
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}

//#Preview("Dark Mode") {
//    NavigationStack {
//        AccessibilityDemoView()
//    }
//    .preferredColorScheme(.dark)
//}
