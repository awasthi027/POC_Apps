//
//  EndpointProviderTests.swift
//  ArchLearningTests
//
//  Verifies endpoints are resolved from Endpoints.plist at runtime rather
//  than hardcoded, and that missing keys/files fail predictably.
//

import Testing
import Foundation
@testable import ArchLearning

struct EndpointProviderTests {
    @Test func resolvesUsersPage2FromBundledPlist() throws {
        let provider = PlistEndpointProvider()

        let url = try provider.url(for: .usersPage2)

        #expect(url.absoluteString == "https://reqres.in/api/users?page=2")
    }

    @Test func throwsWhenPlistResourceIsMissing() {
        let provider = PlistEndpointProvider(resourceName: "DoesNotExist")

        #expect(throws: EndpointProviderError.self) {
            _ = try provider.url(for: .usersPage2)
        }
    }

    @Test func mockProviderThrowsKeyNotFoundForUnregisteredKey() {
        let provider = MockEndpointProvider(urlsByKey: [:])

        #expect(throws: EndpointProviderError.self) {
            _ = try provider.url(for: .usersPage2)
        }
    }

    @Test func mockProviderReturnsConfiguredURL() throws {
        let expected = URL(string: "https://example.com/mock")!
        let provider = MockEndpointProvider(urlsByKey: [.usersPage2: expected])

        let url = try provider.url(for: .usersPage2)

        #expect(url == expected)
    }
}
