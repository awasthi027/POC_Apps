//
//  URLLauncherViewModel.swift
//  ai-concept-learning
//
//  Presentation logic for the URL launcher tab.
//

import Combine
import Foundation

@MainActor
final class URLLauncherViewModel: ObservableObject {

    @Published var targetURLString: String = ""
    @Published var errorMessage: String?

    private let opener: URLOpening

    init(opener: URLOpening) {
        self.opener = opener
    }

    func openEnteredURL() async {
        guard let url = enteredURL() else {
            errorMessage = "Enter a valid URL."
            return
        }
        guard opener.canOpen(url) else {
            errorMessage = "This URL cannot be opened."
            return
        }
        let didOpen = await opener.open(url)
        if !didOpen {
            errorMessage = "Could not open the URL."
        }
    }

    private func enteredURL() -> URL? {
        let trimmed = targetURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let rawValue = normalizedURLString(from: trimmed)
        guard let url = URL(string: rawValue) else {
            return nil
        }
        return url
    }

    private func normalizedURLString(from rawValue: String) -> String {
        if rawValue.contains("://") {
            return rawValue
        }
        return "https://\(rawValue)"
    }
}
