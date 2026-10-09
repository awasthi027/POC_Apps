//
//  LocalUserDataSource.swift
//  ArchLearning
//
//  Abstraction over local caching. SwiftData is the default implementation
//  per current requirements, but any other persistence mechanism can
//  conform to this protocol and be swapped in later.
//

import Foundation
import SwiftData

protocol LocalUserDataSource: Sendable {
    func fetchCachedUsers() async throws -> [UserEntity]
    func save(_ users: [UserEntity]) async throws
    func clearAll() async throws
}

/// Default local data source, backed by SwiftData.
@ModelActor
actor SwiftDataUserDataSource: LocalUserDataSource {
    func fetchCachedUsers() throws -> [UserEntity] {
        let descriptor = FetchDescriptor<UserRecord>(sortBy: [SortDescriptor(\.id)])
        let records = try modelContext.fetch(descriptor)
        return records.map { $0.toEntity() }
    }

    func save(_ users: [UserEntity]) throws {
        try clearAll()
        for user in users {
            modelContext.insert(UserRecord(entity: user))
        }
        try modelContext.save()
    }

    func clearAll() throws {
        let existing = try modelContext.fetch(FetchDescriptor<UserRecord>())
        for record in existing {
            modelContext.delete(record)
        }
        try modelContext.save()
    }
}
