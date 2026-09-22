//
//  APNSLogStore.swift
//  BGTaskLearning
//
//  Created by Ashish Awasthi on 22/09/26.
//

import Foundation
import Combine

class APNSLogStore: ObservableObject {
    static let shared = APNSLogStore()
    
    @Published var logs: [APNSLog] = []
    private let queue = DispatchQueue(label: "com.bgtasklearning.apnslogstore")
    
    struct APNSLog: Identifiable {
        let id: UUID = UUID()
        let message: String
        let timestamp: Date
    }
    
    func add(_ message: String) {
        queue.async { [weak self] in
            DispatchQueue.main.async {
                self?.logs.insert(
                    APNSLog(message: message, timestamp: Date()),
                    at: 0
                )
            }
        }
    }
    
    func clear() {
        queue.async { [weak self] in
            DispatchQueue.main.async {
                self?.logs.removeAll()
            }
        }
    }
}
