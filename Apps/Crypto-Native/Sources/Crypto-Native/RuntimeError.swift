//
//  RuntimeError.swift
//  Crypto-Native
//
//  Created by Ashish Awasthi on 04/02/25.
//

import Foundation


struct RuntimeError: LocalizedError {
    let description: String

    init(_ description: String) {
        self.description = description
    }

    var errorDescription: String? {
        description
    }
}

public extension Collection {
    var isNotEmpty: Bool {
        return self.isEmpty == false
    }
}

public extension Data {

    typealias Bytes = [UInt8]
    static let empty = Data(count: 0)

    static func randomData(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0x00, count: count)
        let _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        let randData = Data(bytes: bytes, count: count)
        bytes.withUnsafeMutableBytes { (pointer: UnsafeMutableRawBufferPointer) -> Void  in
            memset(pointer.baseAddress, 0x00, count)
        }
        return randData
    }

    var toString: String? {
        return String(data: self, encoding: .utf8)
    }

    var bytes: Bytes {
        return Array(self)
    }

    @available(*, deprecated, message: "This method is deprecated and will be removed")
    func unsafeClearContents() {
        self.clearContents()
    }

    internal func clearContents() {
        #if (arch(i386) || arch(arm))
        assert(self.count > 6, "The data size is required to be more than 6, current size: \(self.count)")
        #else
        assert(self.count > 14, "The data size is required to be more than 15, current size: \(self.count)")
        #endif
        #if swift(>=5.0)
        self.withUnsafeBytes { (bufferPointer) in
            guard let baseAddress = bufferPointer.baseAddress else {
                return
            }
            let other = UnsafeMutableRawPointer(mutating: baseAddress)
            memset(other, 0x00, bufferPointer.count)
        }
        #else
        self.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) in
            let other = UnsafeMutableRawPointer(mutating: UnsafeRawPointer(pointer))
            memset(other, 0x00, self.count)
        }
        #endif
    }
}
