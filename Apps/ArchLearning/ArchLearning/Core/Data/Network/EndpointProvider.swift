//
//  EndpointProvider.swift
//  ArchLearning
//
//  Resolves endpoint URLs from Endpoints.plist at runtime instead of
//  hardcoding them in source. Every network-facing data source depends on
//  this protocol, so the backing plist (or any future source — remote
//  config, environment variables, etc.) can be swapped without touching
//  call sites.
//

import Foundation

protocol EndpointProviding: Sendable {
    func url(for key: EndpointKey) throws -> URL
}

enum EndpointProviderError: Error, Equatable {
    case plistNotFound(String)
    case keyNotFound(String)
    case invalidURL(String)
}

struct PlistEndpointProvider: EndpointProviding {
    private let bundle: Bundle
    private let resourceName: String

    init(bundle: Bundle = .main, resourceName: String = "Endpoints") {
        self.bundle = bundle
        self.resourceName = resourceName
    }

    func url(for key: EndpointKey) throws -> URL {
        guard let plistURL = bundle.url(forResource: resourceName, withExtension: "plist") else {
            throw EndpointProviderError.plistNotFound(resourceName)
        }
        guard
            let data = try? Data(contentsOf: plistURL),
            let dictionary = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        else {
            throw EndpointProviderError.plistNotFound(resourceName)
        }
        guard let urlString = dictionary[key.rawValue] else {
            throw EndpointProviderError.keyNotFound(key.rawValue)
        }
        guard let url = URL(string: urlString) else {
            throw EndpointProviderError.invalidURL(urlString)
        }
        return url
    }
}
