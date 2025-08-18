//
//  CrossAppEventNotifier+Center.swift
//  AWCorePlatformHelpers
//
//  Copyright (c) Omnissa, LLC. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the
//  United States and other countries as well as by international treaties.
//  -- Omnissa Restricted
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


internal extension Dictionary {
    static var empty: [Key: Value] {
        return [:]
    }

    /// Adds the value to the specified key if the key is not present already
    /// - Parameters:
    ///   - value: The new value to add to the dictionary.
    ///   - key: The key to associate with `value`.
    /// - Returns: `true` when new value is added (or key is missing in the dictionary before), `false` otherwise
    @discardableResult mutating func add(_ value: Value, onMissingKey key: Key) -> Bool {
        if self[key] != nil {
            return false
        }

        self[key] = value
        return true
    }
}


internal extension CrossAppEventNotifier {

    /// Notification center implementation that can post or observe device wide notifications.
    ///
    /// Implementation is using system provided Darwin Notification Center. Make sure you only observe a kind of
    /// notification once, otherwise observe API will throw.
    ///
    /// To post notification:
    /// `CrossAppEventNotifier.Center.shared.post(<notification>)`
    ///
    /// To observe to any notification:
    /// `CrossAppEventNotifier.Center.shared.observe(<notification>) { notification in /* action */ }`
    ///
    /// To remove observation:
    /// `CrossAppEventNotifier.Center.shared.removeObservation(<notification>)`
    ///
    final class Center: CrossAppNotificationCenter {

        /// Singleton instance of the `CrossAppEventNotifier.Center`
        nonisolated(unsafe) public static var shared = Center()

        /// Dictionary to keep track of the notifications currently observed &
        /// corresponding handlers.
        @Synchronized internal var observations: [Name: Handler] = [:]

        /// Underlying darwin notification center
        private let center: CFNotificationCenter

        /// Private initializer to avoid instantiating multiple times. Multiple instances are blocked because the
        /// `CFNotificationCallback` pointer for observing underlying CFNotificatioName is a C type
        /// callback & cannot capture Swift context. It can invoke only globally accessible instances.
        private init() {
            self.center = CFNotificationCenterGetDarwinNotifyCenter()
        }

        /// Posts the specified notification.
        ///
        /// *Note: If  there's an observer for same CrossAppEventNotifier.Name instance, handler will be called for the same.
        /// Use `CrossAppEventHandler` if you don't want this behaviour*
        /// - Parameter notification: `CrossAppEventNotifier.Name` to be posted
        internal func post(_ notification: CrossAppEventNotifier.Name) {
            CFNotificationCenterPostNotification(
                self.center,
                notification,
                nil /* object: ignored in darwin notification center */,
                nil /* userInfo: ignored in darwin notification center */,
                false /* deliverImmediately: ignored in darwin notification center */
            )
            print( "Posted '\(notification.rawValue)'")
        }

        /// Observe the specified notification. Handler will be called whenever the notification is posted by some apps
        /// (this includes the current app).
        /// - Parameters:
        ///   - notification: `CrossAppEventNotifier.Name` to be observed
        ///   - handler: Handler object of type `CrossAppEventNotifier.Handler` to be invoked
        /// - Throws: Throws `CrossAppEventNotifier.Error.alreadyObserving` when notification is already observing
        internal func observe(_ notification: CrossAppEventNotifier.Name, handler: @escaping CrossAppEventNotifier.Handler) throws {
            guard self.observations.add(handler, onMissingKey: notification) else {
                print( "Notification '\(notification.rawValue)' is already being observed. Not adding new observer.")
                throw CrossAppEventNotifier.Error.alreadyObserving
            }

            let callback: CFNotificationCallback = { (_, _, cfnotificationname, _, _) in
                guard let name = cfnotificationname else {
                    print( "CFNotificationCallback without notification name!")
                    return
                }

                print( "Notification \(name.rawValue) triggered")

                // We cannot use `self` here, as C  pointers cannot capture context.
                Center.shared.notify(name)
            }

            CFNotificationCenterAddObserver(
                self.center,
                Unmanaged.passUnretained(self).toOpaque(), /* We use Center.shared object always to observe  */
                callback,
                notification.rawValue,
                nil, /* object: ignored in darwin notification center */
                .coalesce /* suspensionBehavior: ignored in darwin notification center */
            )
            print( "Added observer for notification \(notification.rawValue)")
        }

        /// Remove observation for the specified notification.
        /// - Parameter notification: Instance of `CrossAppEventNotifier.Name` to be removed from observing
        /// - Throws: Throws `CrossAppEventNotifier.Error.notObserving` when notification is not observed yet.
        internal func removeObservation(_ notification: CrossAppEventNotifier.Name) throws {
            if self.observations.removeValue(forKey: notification) == nil {
                print("Notification '\(notification.rawValue)' is not observed. Cannot remove observer.")
                throw CrossAppEventNotifier.Error.notObserving
            }

            CFNotificationCenterRemoveObserver(
                self.center,
                Unmanaged.passUnretained(self).toOpaque(),
                notification,
                nil /* object: ignored in darwin notification center */
            )

            print("Removed observer for notification \(notification.rawValue)")
        }

        /// Reset all observations
        internal func reset() {
            CFNotificationCenterRemoveEveryObserver(
                self.center,
                Unmanaged.passUnretained(self).toOpaque()
            )

            self.observations.removeAll()
            print( "Removed all observers")
        }

        /// Notifies the handler corresponding to the notification name specified
        /// - Parameter notification: `CrossAppEventNotifier.Name` for invoking the handler
        private func notify(_ notification: CrossAppEventNotifier.Name) {
            if let handler = self.observations[notification] {
                handler(notification)
                return
            }

            print( "Notification '\(notification.rawValue)' seems not observed anymore. Failed to call the handler.")
        }
    }
}

