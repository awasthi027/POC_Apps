//
//  SpeechRecognizerManager.swift
//  TextToSpeechClassifier
//
//  Created by Ashish Awasthi on 06/05/26.
//

import Foundation
internal import Speech
import AVFoundation
import Combine

@MainActor
class SpeechRecognizerManager: ObservableObject {

    // MARK: - Published Properties
    @Published var transcribedText: String = ""
    @Published var isRecording: Bool = false
    @Published var errorMessage: String? = nil
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    // MARK: - Supported Languages
    struct SupportedLanguage: Identifiable, Hashable {
        let id: String       // BCP-47 locale identifier
        let displayName: String
    }

    static let supportedLanguages: [SupportedLanguage] = [
        SupportedLanguage(id: "en-US", displayName: "English (US)"),
        SupportedLanguage(id: "en-GB", displayName: "English (UK)"),
        SupportedLanguage(id: "hi-IN", displayName: "Hindi (India)"),
        SupportedLanguage(id: "fr-FR", displayName: "French (France)"),
        SupportedLanguage(id: "de-DE", displayName: "German (Germany)"),
        SupportedLanguage(id: "es-ES", displayName: "Spanish (Spain)"),
        SupportedLanguage(id: "zh-CN", displayName: "Chinese (Simplified)"),
        SupportedLanguage(id: "ja-JP", displayName: "Japanese (Japan)"),
        SupportedLanguage(id: "ko-KR", displayName: "Korean (Korea)"),
        SupportedLanguage(id: "pt-BR", displayName: "Portuguese (Brazil)"),
        SupportedLanguage(id: "it-IT", displayName: "Italian (Italy)"),
        SupportedLanguage(id: "ar-SA", displayName: "Arabic (Saudi Arabia)"),
    ]

    @Published var selectedLanguage: SupportedLanguage = SupportedLanguage(id: "en-US", displayName: "English (US)")

    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Authorization
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.authorizationStatus = status
                if status != .authorized {
                    self?.errorMessage = "Speech recognition authorization denied. Please enable it in Settings."
                }
            }
        }
    }

    // MARK: - Start Recording
    func startRecording() {
        guard authorizationStatus == .authorized else {
            errorMessage = "Speech recognition not authorized."
            return
        }

        // Reset previous state
        stopRecording()
        transcribedText = ""
        errorMessage = nil

        // Setup recognizer for selected language
        let locale = Locale(identifier: selectedLanguage.id)
        speechRecognizer = SFSpeechRecognizer(locale: locale)

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available for \(selectedLanguage.displayName)."
            return
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session error: \(error.localizedDescription)"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
            if let error {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                    self.stopRecording()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Audio engine failed to start: \(error.localizedDescription)"
        }
    }

    // MARK: - Stop Recording
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Clear
    func clearText() {
        transcribedText = ""
        errorMessage = nil
    }

    deinit {
        // Synchronous cleanup without MainActor
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}
