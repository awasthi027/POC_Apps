//
//  OnlineService.swift
//  APNSLearning
//
//  Created by Ashish Awasthi on 13/09/26.
//

import Foundation

protocol OnlineService {
    func fetchMessages() async throws -> [APNSMessageDTO]
    func markMessageAsRead(id: String) async throws
}

struct APNSMessageDTO: Codable {
    let id: String
    let title: String
    let body: String
    let receivedAt: Date
    let payload: String
}

class DefaultOnlineService: OnlineService {
    func fetchMessages() async throws -> [APNSMessageDTO] {
        // Simulated API call
        return []
    }
    
    func markMessageAsRead(id: String) async throws {
        // Simulated API call to sync read status
    }
}
