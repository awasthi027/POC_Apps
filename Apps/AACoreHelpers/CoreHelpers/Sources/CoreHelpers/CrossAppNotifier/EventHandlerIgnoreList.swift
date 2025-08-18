//
//  EventHandlerIgnoreList.swift
//  AWCorePlatformHelpers
//
//  Copyright (c) Omnissa, LLC. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the
//  United States and other countries as well as by international treaties.
//  -- Omnissa Restricted
//

import Foundation

/// Handles logic for events to be ignored for `CrossAppEventHandler`
internal struct EventHandlerIgnoreList {

    /// Actual list of events & meta data like expiry & count
    private var list: [CrossAppEvent: (count: Int, expiry: Date)] = [:]

    /// Unfair lock for synchronizing the operations
    private let lock = UnfairLock()

    /// Add event to the ignore list
    /// - Parameters:
    ///   - event: Event to be ignored
    ///   - time: Time interval in seconds to be ignored from the invocation time
    mutating func ignoreObservation(of event: CrossAppEvent, for time: TimeInterval) {
        self.lock.withLocked {
            var currentCount = 0
            if let ignoredEvent = self.list[event], ignoredEvent.expiry > Date()  {
                currentCount = ignoredEvent.count
            }

            self.list[event] = (count: currentCount + 1, expiry: Date().addingTimeInterval(time))
            print( "Added \(event) to the ignore list for \(currentCount + 1) times")
        }
    }

    /// Mark a particular event ignored & remove it from the list
    /// - Parameter event: Event that needs to be marked
    /// - Returns: `true` when a valid event was in ignore list & marked it ignored. `false` otherwise when
    ///             event is not there in ignore list or is expired.
    mutating func markIgnored(for event: CrossAppEvent) -> Bool {
        self.lock.withLocked {
            guard let ignoredEvent = self.list[event] else {
                print("Event \(event) not found in ignored list")
                return false
            }

            let currentCount = ignoredEvent.count
            guard currentCount > 0 else {
                self.list.removeValue(forKey: event)
                return false
            }

            guard ignoredEvent.expiry > Date() else {
                self.list.removeValue(forKey: event)
                print("Event \(event) expired from ignore list")
                return false
            }

            if currentCount == 1 {
                self.list.removeValue(forKey: event)
            } else {
                self.list[event] = (count: currentCount - 1, expiry: ignoredEvent.expiry)
            }

            print( "Ignoring event \(event)")
            return true
        }
    }

    /// Reset the ignored list
    mutating func reset() {
        print( "Resetting list")
        self.lock.withLocked {
            self.list.removeAll()
        }
    }
}
