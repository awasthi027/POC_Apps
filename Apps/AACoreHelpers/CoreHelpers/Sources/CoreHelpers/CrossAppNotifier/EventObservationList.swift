//
//  EventObservationList.swift
//  AWCorePlatformHelpers
//
//  Copyright (c) Omnissa, LLC. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the
//  United States and other countries as well as by international treaties.
//  -- Omnissa Restricted
//

import Foundation

/// Container for observations related to `CrossAppEventHandler`
internal struct EventObservationList {

    /// Actual list of observations
    private var list: [CrossAppEventObservation] = []

    /// Unfair lock for synchronizing the operations
    private let lock = UnfairLock()

    /// Add specified observation to the list
    /// - Parameter observation: Observation instance
    /// - Returns: `true` when the event is already observed, `false` otherwise
    mutating func add(_ observation: CrossAppEventObservation) -> Bool {
        self.lock.withLocked {
            let observing = self.list.first(where: { $0.event == observation.event }) != nil
            self.list.append(observation)
            print("Adding observation with ID \(observation.id.uuidString). Already observing event: \(observing)")
            return observing
        }
    }

    /// Remove a particular observation from the list
    /// - Parameter observation: Observation instance
    mutating func remove(_ observation: CrossAppEventObservation) {
        self.lock.withLocked {
            if let index = self.list.firstIndex(where: { $0 == observation }) {
                print("Removing observation with ID \(observation.id.uuidString).")
                self.list.remove(at: index)
            } else {
                print( "Observation \(observation) not found to be removed")
            }
        }
    }

    func isObserving(event: CrossAppEvent) -> Bool {
        self.lock.withLocked {
            self.list.first(where: { $0.event == event}) != nil
        }
    }

    func executeHandlers(for event: CrossAppEvent) {
        self.lock.withLocked {
            self.list
                .filter { $0.event == event }
                .forEach { observation in
                    observation.queue.async {
                        observation.handler(event)
                    }
                }
        }
    }

    /// Reset all the observations
    /// - Returns: Returns the list
    mutating func reset() -> [CrossAppEventObservation] {
        print("Resetting list")
        return self.lock.withLocked {
            let observations = self.list
            self.list.removeAll()
            return observations
        }
    }
}
