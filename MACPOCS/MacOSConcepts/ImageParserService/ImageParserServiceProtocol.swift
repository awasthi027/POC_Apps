//
//  ImageParserServiceProtocol.swift
//  ImageParserService
//
//  Created by Ashish Awasthi on 27/08/26.
//

import Foundation

/// The wire contract between the host app and this service. This exact file
/// must also be a member of the app target (File Inspector > Target
/// Membership > check MacOSConcepts too) — both processes have to compile
/// the identical declaration for NSXPCInterface to agree on the interface.
@objc protocol ImageParserServiceProtocol {
    func parseImage(_ data: Data, withReply reply: @escaping (Int, Int) -> Void)
}
