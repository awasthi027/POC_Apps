//
//  EndpointKey.swift
//  ArchLearning
//
//  Keys used to look up endpoint URLs from Endpoints.plist. Adding a new
//  endpoint means adding a case here + a matching key/value in the plist —
//  no URL strings are ever hardcoded in Swift source.
//

import Foundation

enum EndpointKey: String {
    case usersPage2 = "UsersPage2"
}
