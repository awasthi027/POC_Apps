//
//  SpeechSynthesisFeatureView.swift
//  TextToSpeechClassifier
//

import SwiftUI
import AVFoundation

struct SpeechSynthesisFeatureView: View {

    @State private var inputText = "Hello. This is a speech synthesis demo."
    @State private var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate

    private let synthesizer = AVSpeechSynthesizer()

    var body: some View {
        Form {
            Section("Input") {
                TextEditor(text: $inputText)
                    .frame(minHeight: 120)
            }

            Section("Voice") {
                HStack {
                    Text("Rate")
                    Slider(value: $speechRate, in: 0.4...0.6)
                }
            }

            Section("Actions") {
                Button("Speak") {
                    speakText()
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Stop") {
                    synthesizer.stopSpeaking(at: .immediate)
                }
                .tint(.red)
            }
        }
        .navigationTitle("Speech Synthesis")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func speakText() {
        let utterance = AVSpeechUtterance(string: inputText)
        utterance.rate = speechRate
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.identifier)
        synthesizer.speak(utterance)
    }
}

#Preview {
    NavigationStack {
        SpeechSynthesisFeatureView()
    }
}
