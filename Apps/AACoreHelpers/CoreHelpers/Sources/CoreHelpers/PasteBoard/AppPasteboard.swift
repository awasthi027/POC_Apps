//
//  AppPasteboard.swift
//  Pods
//
//  Created by Ashish Awasthi on 14/08/25.
//
import Foundation
import UIKit

enum RestrictionMessage {
    
    case  disablePasteOut
    case  disablePasteIn

    var message: String {
        switch self {
        case .disablePasteOut: return "Your admin has restricted the copied content to be only accessible within Organization applications."
        case .disablePasteIn: return "Your admin has disallowed pasting from unmanaged sources."
        }
    }
}

final class AppPasteboard {
    // Singleton instance
    static let shared = AppPasteboard()

    private init() {
        setupProtection()
    }

    private func setupProtection() {
        // Clear system pasteboard when app enters background
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.clearPasteboard()
        }
    }

    // Internal storage
    private var storage: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.yourapp.pasteboard.queue", attributes: .concurrent)

    // MARK: - Public Interface

    var string: String? {
        get { queue.sync { storage["string"] as? String } }
        set { queue.async(flags: .barrier) { self.storage["string"] = newValue } }
    }

    var strings: [String]? {
        get { queue.sync { storage["strings"] as? [String] } }
        set { queue.async(flags: .barrier) { self.storage["strings"] = newValue } }
    }

    // Add other types as needed (images, URLs, etc.)

    @objc func clearPasteboard() {
        queue.async(flags: .barrier) {
            self.storage.removeAll()
        }
    }

    // MARK: - Copy/Paste Management

    func performInternalCopy(_ text: String) {
        self.string = text
        // Optionally add metadata
        let metadata = ["source": "internal", "timestamp": Date().timeIntervalSince1970] as [String : Any]
        queue.async(flags: .barrier) {
            self.storage["metadata"] = metadata
        }
    }

    func isInternalPaste() -> Bool {
        return queue.sync {
            if let metadata = storage["metadata"] as? [String: Any],
               let source = metadata["source"] as? String,
               source == "internal" {
                return true
            }
            return false
        }
    }
}
