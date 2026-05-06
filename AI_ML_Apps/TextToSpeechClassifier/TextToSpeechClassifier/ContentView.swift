//
//  ContentView.swift
//  TextToSpeechClassifier
//
//  Created by Ashish Awasthi on 06/05/26.
//

import SwiftUI

private struct SpeechFeature: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let iconName: String
}

struct ContentView: View {

    private let features: [SpeechFeature] = [
        SpeechFeature(
            id: "speech_to_text",
            title: "Speech to Text",
            description: "Transcribe spoken audio into text with source language selection.",
            iconName: "mic.fill"
        ),
        SpeechFeature(
            id: "authorization",
            title: "Authorization",
            description: "Review and request Speech framework permission status.",
            iconName: "lock.shield.fill"
        ),
        SpeechFeature(
            id: "supported_locales",
            title: "Supported Locales",
            description: "Browse all locales currently supported by speech recognition.",
            iconName: "globe.americas.fill"
        ),
        SpeechFeature(
            id: "on_device",
            title: "On-Device Recognition",
            description: "Check whether selected locales support on-device transcription.",
            iconName: "iphone.gen3"
        ),
        SpeechFeature(
            id: "speech_synthesis",
            title: "Speech Synthesis",
            description: "Convert text into spoken audio with AVSpeechSynthesizer.",
            iconName: "speaker.wave.2.fill"
        )
    ]

    var body: some View {
        NavigationStack {
            List(features) { feature in
                NavigationLink {
                    destinationView(for: feature.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: feature.iconName)
                            .font(.title3)
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.title)
                                .font(.headline)
                            Text(feature.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Speech Features")
        }
    }

    @ViewBuilder
    private func destinationView(for featureID: String) -> some View {
        switch featureID {
        case "speech_to_text":
            SpeechToTextFeatureView()
        case "authorization":
            SpeechAuthorizationFeatureView()
        case "supported_locales":
            SupportedLocalesFeatureView()
        case "on_device":
            OnDeviceRecognitionFeatureView()
        case "speech_synthesis":
            SpeechSynthesisFeatureView()
        default:
            Text("Feature not found")
        }
    }
}

#Preview {
    ContentView()
}
