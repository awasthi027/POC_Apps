//
//  SpeechAuthorizationFeatureView.swift
//  TextToSpeechClassifier
//

import SwiftUI
internal import Speech

struct SpeechAuthorizationFeatureView: View {

    @State private var status: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()

    var body: some View {
        List {
            Section("Current Status") {
                Label(statusTitle, systemImage: statusIcon)
                    .foregroundStyle(statusColor)
                Text(statusDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Action") {
                Button("Request Permission") {
                    requestPermission()
                }
            }
        }
        .navigationTitle("Authorization")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusTitle: String {
        switch status {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }

    private var statusIcon: String {
        switch status {
        case .authorized: return "checkmark.shield.fill"
        case .denied: return "xmark.shield.fill"
        case .restricted: return "exclamationmark.shield.fill"
        case .notDetermined: return "questionmark.shield.fill"
        @unknown default: return "questionmark"
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized: return .green
        case .denied: return .red
        case .restricted: return .orange
        case .notDetermined: return .secondary
        @unknown default: return .secondary
        }
    }

    private var statusDescription: String {
        switch status {
        case .authorized:
            return "Speech recognition is available for this app."
        case .denied:
            return "Permission was denied. You can enable it from iOS Settings."
        case .restricted:
            return "Speech recognition is restricted on this device."
        case .notDetermined:
            return "Permission has not been requested yet."
        @unknown default:
            return "Unknown permission state."
        }
    }

    private func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { newStatus in
            DispatchQueue.main.async {
                status = newStatus
            }
        }
    }
}

#Preview {
    NavigationStack {
        SpeechAuthorizationFeatureView()
    }
}
