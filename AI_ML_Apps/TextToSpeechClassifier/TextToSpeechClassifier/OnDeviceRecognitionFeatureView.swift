//
//  OnDeviceRecognitionFeatureView.swift
//  TextToSpeechClassifier
//

import SwiftUI
internal import Speech

struct OnDeviceRecognitionFeatureView: View {

    @State private var selectedLanguage = SpeechRecognizerManager.supportedLanguages.first

    var body: some View {
        Form {
            Section("Language") {
                Picker("Source Language", selection: $selectedLanguage) {
                    ForEach(SpeechRecognizerManager.supportedLanguages, id: \.self) { language in
                        Text(language.displayName).tag(Optional(language))
                    }
                }
            }

            Section("On-Device Availability") {
                if let selectedLanguage {
                    Label(
                        supportsOnDeviceRecognition(for: selectedLanguage.id) ? "Supported" : "Not Supported",
                        systemImage: supportsOnDeviceRecognition(for: selectedLanguage.id) ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(supportsOnDeviceRecognition(for: selectedLanguage.id) ? .green : .red)

                    Text(selectedLanguage.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Note") {
                Text("On-device support depends on iOS version, language model availability, and device hardware.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("On-Device")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func supportsOnDeviceRecognition(for localeID: String) -> Bool {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeID)) else {
            return false
        }
        return recognizer.supportsOnDeviceRecognition
    }
}

#Preview {
    NavigationStack {
        OnDeviceRecognitionFeatureView()
    }
}
