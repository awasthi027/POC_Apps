//
//  WebSessionCleaner.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 28/07/26.
//

import Foundation
import WebKit

/// Utility for wiping any persisted WKWebView browsing session (cookies, caches, local
/// storage, etc.). Used at app launch so each run starts from a clean, unauthenticated state.
enum WebSessionCleaner {

    /// Removes all website data from the default (persistent) data store, along with shared
    /// HTTP cookies and the shared URL cache.
    /// - Parameter completion: Called on the main thread once clearing has finished.
    @MainActor
    static func clearAllSessions(completion: (() -> Void)? = nil) {
        let dataStore = WKWebsiteDataStore.default()
        let allDataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.fetchDataRecords(ofTypes: allDataTypes) { records in
            dataStore.removeData(ofTypes: allDataTypes, for: records) {
                HTTPCookieStorage.shared.cookies?.forEach {
                    HTTPCookieStorage.shared.deleteCookie($0)
                }
                URLCache.shared.removeAllCachedResponses()
                print("WebSessionCleaner: cleared \(records.count) website data record(s).")
                completion?()
            }
        }
    }
}
