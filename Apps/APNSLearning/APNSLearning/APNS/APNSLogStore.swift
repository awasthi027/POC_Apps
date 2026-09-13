//
//  APNSLogStore.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import Foundation
import Combine

@MainActor
final class APNSLogStore: ObservableObject {
    static let shared = APNSLogStore()

    @Published private(set) var logs: [String] = []

    func add(_ message: String) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        logs.append("[\(timestamp)] \(message)")
    }
}
