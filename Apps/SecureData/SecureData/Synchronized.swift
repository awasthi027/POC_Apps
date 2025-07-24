//
//  Synchronized.swift
//  SecureData
//
//  Created by Ashish Awasthi on 15/06/25.
//

import Foundation

/// A wrapper of `Darwin.os_unfair_lock_t`.
/// Since `Darwin.os_unfair_lock_t` is a C struct,
/// this class wrapper guarantees the heap allocation
public final class UnfairLock {
    private let unfairLock: Darwin.os_unfair_lock_t

    public init() {
        self.unfairLock = .allocate(capacity: 1)
        self.unfairLock.initialize(to: Darwin.os_unfair_lock())
    }

    deinit {
        self.unfairLock.deinitialize(count: 1)
        self.unfairLock.deallocate()
    }

    /// wrapper function of `Darwin.os_unfair_lock_lock()`
    public func lock() {
        Darwin.os_unfair_lock_lock(self.unfairLock)
    }

    /// wrapper function of `Darwin.os_unfair_lock_unlock()`
    public func unlock() {
        Darwin.os_unfair_lock_unlock(self.unfairLock)
    }

    @discardableResult
    public func withLocked<Result>(unlockAfter execute: () throws -> Result) rethrows -> Result {
        self.lock()
        defer { self.unlock() }
        return try execute()
    }
}

@propertyWrapper
/// The helper type that uses coroutine to provide thread-safe
/// accessing to its wrapped value.
/// Making it a property wrapper to avoid explicit modification function calling
public class Synchronized<Value> {
    private var storage: Value
    private let lock = UnfairLock()

    public init(wrappedValue: Value) {
        self.storage = wrappedValue
    }

    public var wrappedValue: Value {
        get {
            self.lock.withLocked { self.storage }
        }

        _modify {
            self.lock.lock()
            defer { self.lock.unlock() }
            yield &self.storage
        }
    }
}
