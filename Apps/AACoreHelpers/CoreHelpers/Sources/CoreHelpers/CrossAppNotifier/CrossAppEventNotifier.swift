//
//  CrossAppEventNotifier.swift
//  AWCorePlatformHelpers
//
//  Copyright (c) Omnissa, LLC. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the
//  United States and other countries as well as by international treaties.
//  -- Omnissa Restricted
//

import Foundation

/// Namespace for the feature of sending & receiving cross app notification
internal enum CrossAppEventNotifier {

    /// Abstraction for underlying system type
    internal typealias Name = CFNotificationName

    /// Alias for handler object for the cross app notifiers
    internal typealias Handler = (Name) -> Swift.Void

    /// Errors associated with CrossAppNotificationCenter. These errors are related to the implementation
    /// of the `CrossAppEventNotifier.Center` that it can observe a notification once.
    internal enum Error: Swift.Error {

        /// Thrown when a `CrossAppEventNotifier.Name` is already being observed by the `Center` and
        /// trying to observe again.
        case alreadyObserving

        /// Thrown when  `CrossAppEventNotifier.Name` is not observed by the `Center`, but trying to
        /// remove observation
        case notObserving
    }
}

internal extension CrossAppEventNotifier.Name {

    /// Convinience initializer for `CrossAppEventNotifier.Name` with `Swift.String`
    init(_ name: String) {
        self.init(name as CFString)
    }
}

/// Interface for supporting cross application notifications using a notification center.
///
/// This provides interfaces for posting & observing of an event / notification of type `CrossAppEventNotifier.Name`
internal protocol CrossAppNotificationCenter {

    /// Posts the specified notification
    func post(_ notification: CrossAppEventNotifier.Name)

    /// Observe the specified notification. Handler will be called whenever the notification is posted by some apps
    func observe(_ notification: CrossAppEventNotifier.Name, handler: @escaping CrossAppEventNotifier.Handler) throws

    /// Remove observation to a particular notification
    func removeObservation(_ notification: CrossAppEventNotifier.Name) throws
}

