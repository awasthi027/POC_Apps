//
//  SupportedLocalesFeatureView.swift
//  TextToSpeechClassifier
//

import SwiftUI
internal import Speech

struct SupportedLocalesFeatureView: View {

    private let localeIDs: [String] = SFSpeechRecognizer.supportedLocales()
        .map { $0.identifier }
        .sorted()

    var body: some View {
        List {
            Section {
                Text("Total locales: \(localeIDs.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Locales") {
                ForEach(localeIDs, id: \.self) { localeID in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Locale.current.localizedString(forIdentifier: localeID) ?? localeID)
                            .font(.body)
                        Text(localeID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("Supported Locales")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SupportedLocalesFeatureView()
    }
}
