//
//  SpeechToTextFeatureView.swift
//  TextToSpeechClassifier
//

import SwiftUI
import UIKit
internal import Speech

struct SpeechToTextFeatureView: View {

    @StateObject private var manager = SpeechRecognizerManager()
    @State private var copyConfirmed = false

    var body: some View {
        VStack(spacing: 0) {
            languageSelectorView
                .padding(.horizontal)
                .padding(.top, 12)

            Divider().padding(.top, 12)

            transcriptView
                .padding(.horizontal)
                .padding(.top, 8)

            Spacer()

            if let error = manager.errorMessage {
                errorBanner(error)
                    .padding(.horizontal)
            }

            controlsView
                .padding(.bottom, 40)
        }
        .navigationTitle("Speech to Text")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            manager.requestAuthorization()
        }
    }

    private var languageSelectorView: some View {
        HStack {
            Label("Language", systemImage: "globe")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Menu {
                ForEach(SpeechRecognizerManager.supportedLanguages) { language in
                    Button {
                        if manager.isRecording { manager.stopRecording() }
                        manager.selectedLanguage = language
                    } label: {
                        HStack {
                            Text(language.displayName)
                            if language.id == manager.selectedLanguage.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(manager.selectedLanguage.displayName)
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
            }
            .disabled(manager.isRecording)
        }
    }

    private var transcriptView: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .frame(maxWidth: .infinity, minHeight: 280)

            if manager.transcribedText.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 44))
                        .foregroundStyle(.tertiary)
                    Text(manager.isRecording ? "Listening..." : "Tap the microphone button to start speaking")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 280)
                .padding()
            } else {
                ScrollView {
                    Text(manager.transcribedText)
                        .font(.body)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut, value: manager.transcribedText)
                }
                .frame(maxWidth: .infinity, minHeight: 280, maxHeight: 320)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer()
            Button {
                manager.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(.systemYellow).opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 8)
    }

    private var controlsView: some View {
        VStack(spacing: 16) {
            Button {
                if manager.isRecording {
                    manager.stopRecording()
                } else {
                    manager.startRecording()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(manager.isRecording ? Color.red.opacity(0.15) : Color.accentColor.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Circle()
                        .stroke(manager.isRecording ? Color.red : Color.accentColor, lineWidth: 3)
                        .frame(width: 80, height: 80)
                    Image(systemName: manager.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(manager.isRecording ? .red : .accentColor)
                        .symbolEffect(.pulse, isActive: manager.isRecording)
                }
            }
            .disabled(manager.authorizationStatus != .authorized)

            Text(manager.isRecording ? "Tap to Stop" : "Tap to Speak")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 24) {
                Button {
                    UIPasteboard.general.string = manager.transcribedText
                    withAnimation { copyConfirmed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation { copyConfirmed = false }
                    }
                } label: {
                    Label(copyConfirmed ? "Copied!" : "Copy", systemImage: copyConfirmed ? "checkmark" : "doc.on.doc")
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
                .disabled(manager.transcribedText.isEmpty)

                Button {
                    manager.clearText()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Capsule())
                }
                .disabled(manager.transcribedText.isEmpty)
                .tint(.red)
            }
        }
        .padding(.top, 16)
    }
}

#Preview {
    NavigationStack {
        SpeechToTextFeatureView()
    }
}
