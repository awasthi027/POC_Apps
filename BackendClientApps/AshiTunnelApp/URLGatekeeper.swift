import Foundation
import Combine
import UIKit

@MainActor
final class URLGatekeeper: ObservableObject {
    @Published var pendingURL: URL?
    @Published var isPromptVisible = false
    @Published var statusMessage = "No URL processed yet."

    func handleIncomingURL(_ incomingURL: URL) {
        guard let targetURL = resolveTargetURL(from: incomingURL) else {
            statusMessage = "Rejected unsupported URL."
            return
        }

        pendingURL = targetURL
        isPromptVisible = true
    }

    func approvePendingURL() {
        guard let url = pendingURL else { return }

        UIApplication.shared.open(url) { [weak self] didOpen in
            guard let self else { return }
            Task { @MainActor in
                self.statusMessage = didOpen
                    ? "Approved: \(url.absoluteString)"
                    : "Failed to open: \(url.absoluteString)"
                self.clearPendingState()
            }
        }
    }

    func denyPendingURL() {
        if let url = pendingURL {
            statusMessage = "Denied: \(url.absoluteString)"
        } else {
            statusMessage = "Denied."
        }

        clearPendingState()
    }

    private func clearPendingState() {
        pendingURL = nil
        isPromptVisible = false
    }

    private func resolveTargetURL(from incomingURL: URL) -> URL? {
        if isWebURL(incomingURL) {
            return incomingURL
        }

        // Supports wrapper format: myapp://open?url=https%3A%2F%2Fapple.com
        guard let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false),
              let wrapped = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let decoded = wrapped.removingPercentEncoding,
              let targetURL = URL(string: decoded),
              isWebURL(targetURL)
        else {
            return nil
        }

        return targetURL
    }

    private func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
