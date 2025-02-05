//
//  Smaug.swift
//  Crypto-Native
//
//  Created by Ashish Awasthi on 04/02/25.
//

import Foundation

public struct Smaug {

    internal struct ManagedMemoryInformation {
        let location: UnsafeMutableRawPointer
        let size: Int
    }

    internal struct SmaugMetrics {
        var tracked: UInt32 = 0
        var untracked: UInt32 = 0
    }

    internal static var internalSerialQueue: DispatchQueue = DispatchQueue.init(label: "com.sdk.queue.internal.SecuredData")
    internal static var dataTracker: [ManagedMemoryInformation] = []
    internal static var metrics = SmaugMetrics()

    private let _securedData: Data

    #if swift(>=5.0)
    @inline(never)
    public var securedData: Data {
        return _securedData
    }
    #else
    public var securedData: Data {
        return _securedData
    }
    #endif

    public let count: Int
    static func track(memoryAddress: UnsafeMutableRawPointer, size: Int, function: String, file: String, line: UInt) {
        Smaug.internalSerialQueue.sync {
            let managed: ManagedMemoryInformation =  Smaug.ManagedMemoryInformation(location: memoryAddress, size: size)
            Smaug.dataTracker.append(managed)
            Smaug.metrics.tracked += 1
        }
    }

    static func untrack(memoryAddress: UnsafeMutableRawPointer, count: Int) {
        Smaug.internalSerialQueue.sync {
            memset(memoryAddress, 0x00, count)

            if let index = Smaug.dataTracker.firstIndex(where: { $0.location == memoryAddress }) {
                Smaug.dataTracker.remove(at: index)
            }
            Smaug.metrics.untracked += 1
            free(memoryAddress)
        }
    }

    static let dataDeallocator = Data.Deallocator.custom(Smaug.untrack(memoryAddress:count:))
    private init(ownedBuffer: UnsafeMutableRawPointer, size: Int, function: String, file: String, line: UInt) {
        Smaug.track(memoryAddress: ownedBuffer, size: size, function: function, file: file, line: line)
        self._securedData = Data(bytesNoCopy: ownedBuffer,
                                 count: size,
                                 deallocator: Smaug.dataDeallocator)
        self.count = size
    }

    public init?(data: inout Data,
                 function: String = #function,
                 file: String = #file,
                 line: UInt = #line) {
        guard data.isNotEmpty else {
            return nil
        }
        defer {
            #if (arch(i386) || arch(arm))
            let minimumRequiredSizeToClear = 6
            #else
            let minimumRequiredSizeToClear = 14
            #endif
            if data.count > minimumRequiredSizeToClear {
                data.clearContents()
            }
        }
        var bytes = data.bytes
        self.init(bytes: &bytes,
                  function: function,
                  file: file,
                  line: line)
    }

    public init?(bytes: inout [UInt8],
                 function: String = #function,
                 file: String = #file,
                 line: UInt = #line) {
        let dataSize = bytes.count
        guard dataSize > 0,
              let buffer = malloc(dataSize) else {
            return nil
        }
        memcpy(buffer, &bytes, dataSize)
        memset(&bytes, 0x00, dataSize)
        self.init(ownedBuffer: buffer,
                  size: dataSize,
                  function: function,
                  file: file,
                  line: line)
    }

    static public func clearAllSecuredContents() {
        Smaug.internalSerialQueue.sync {
            Smaug.dataTracker.forEach { (memory) in
                memset(memory.location, 0x0, memory.size)
            }
        }
    }
}

extension Smaug {
    // MARK: Metrics accessor methods
    static public var numberOfSecuredObjectsCurrentlyInMemory: Int {
        var result = 0
        Smaug.internalSerialQueue.sync {
            result = Smaug.dataTracker.count
        }
        return result
    }

    static public var numberOfSecureObjectsInstantiated: UInt32 {
        var result: UInt32 = 0
        Smaug.internalSerialQueue.sync {
            result = Smaug.metrics.tracked
        }
        return result
    }

    static public var numberOfSecureObjectsReleased: UInt32 {
        var result: UInt32 = 0
        Smaug.internalSerialQueue.sync {
            result = Smaug.metrics.untracked
        }
        return result
    }

    static internal func areSecureItemsInBalance() -> Bool {
        var totalSecureItemBalance = false
        Smaug.internalSerialQueue.sync {
            let allInstantiatedItems = Smaug.metrics.tracked
            let allDeallocatedAndCurrentItems = Smaug.metrics.untracked + UInt32(Smaug.dataTracker.count)
            totalSecureItemBalance = allInstantiatedItems == allDeallocatedAndCurrentItems
        }
        return totalSecureItemBalance
    }
}

