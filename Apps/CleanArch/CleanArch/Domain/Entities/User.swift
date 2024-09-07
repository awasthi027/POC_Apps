//
//  User.swift
//  CleanArch
//
//  Created by Ashish Awasthi on 30/08/24.
//
//The Domain layer contains the core business logic, including entities and use cases.

import Foundation

struct User: Decodable, Identifiable {
    let id: Int
    let name: String
}
