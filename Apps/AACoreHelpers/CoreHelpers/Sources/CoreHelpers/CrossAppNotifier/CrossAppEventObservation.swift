//
//  CrossAppEventHandler.swift
//  AWCorePlatformHelpers
//
//  Copyright (c) Omnissa, LLC. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the
//  United States and other countries as well as by international treaties.
//  -- Omnissa Restricted
//

import Foundation

public extension DispatchQueue {

    static let network = DispatchQueue(label: "com.air-watch.network",
                                       qos: DispatchQoS.utility,
                                       attributes: DispatchQueue.Attributes.concurrent,
                                       autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                                       target: nil)

    static let background =  DispatchQueue(label: "com.air-watch.background",
                                           qos: DispatchQoS.background,
                                           attributes: DispatchQueue.Attributes.concurrent,
                                           autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                                           target: nil)

    static let highPriority = DispatchQueue(label: "com.air-watch.high-priority",
                                            qos: DispatchQoS.userInitiated,
                                            attributes: DispatchQueue.Attributes.concurrent,
                                            autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                                            target: nil)

    static let serial = DispatchQueue(label: "com.air-watch.global.serial-queue",
                                      qos: DispatchQoS.userInteractive,
                                      attributes: [],
                                      autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                                      target: nil)
}

public typealias CrossAppEvent = String

private extension CrossAppEvent {
    var notification: CrossAppEventNotifier.Name {
        .init(self)
    }
}

/// An interface for storing observation detail related to `CrossAppEventHandler`.
///
/// Instance of this struct can be used to remove observation for an event.
public struct CrossAppEventObservation: Identifiable, Equatable, CustomDebugStringConvertible {
    /// An identifier for the observation
    public let id: UUID = .init()

    /// Event name being observed
    internal let event: CrossAppEvent

    /// Handler to be executed on the specified event
    internal let handler: CrossAppEventHandler.Handler

    /// Queue in which handler to be executed
    internal let queue: DispatchQueue

    public static func == (lhs: CrossAppEventObservation, rhs: CrossAppEventObservation) -> Bool {
        lhs.id == rhs.id
    }

    public var debugDescription: String {
        "Event Observation - [\(self.id.uuidString)] \(event)"
    }
}

/// Event handler for sending & receiving events across apps & extensions. Events should be represented by
/// `Swift.String`. Internally uses `CrossAppEventNotifier.Center` as a provider for notifications.
///
/// **Usage:**
///
/// Sending events:
/// `CrossAppEventHandler.shared.send("ws1sdk.event")`
///
/// Simplest usage of observing for events:
/// `let observation = CrossAppEventHandler.shared.on("ws1sdk.event") { /* Event handler */ }`
///
/// You'll need `observation` instance to remove observing the event.
/// `CrossAppEventHandler.shared.remove(observation: observation)`
///
/// **Event triggered when app is in background**
///
/// All the events triggered by other apps when observing app is in background will get delivered just before application
/// becomes active. In case application do not need these events, you can ignore by checking current app state.
/// ```
/// CrossAppEventHandler.shared.on(ws1sdk.event) {
///    guard UIApplication.shared.applicationState == .active else {
///         // Ignore events triggered when app is in backgrond
///         return
///    }
/// }
/// ```
public final class CrossAppEventHandler {

    /// Handler for the observation
    public typealias Handler = (CrossAppEvent) -> Swift.Void

    /// List of all observations currently in place
    internal var observations: EventObservationList = .init()

    /// Handles the list of events that need to be ignored.
    /// Used to ignore the events sent by this instance of the `CrossAppEventHandler`, so that observers are not notified.
    internal var ignoreList: EventHandlerIgnoreList = .init()

    /// Underlying notification center implementation for Darwin Notification
    internal var notificationCenter: CrossAppNotificationCenter = CrossAppEventNotifier.Center.shared

    /// Singleton instance of the `CrossAppEventHandler`
    nonisolated(unsafe) public static let shared: CrossAppEventHandler = .init()

    /// Blocking initializer to honor singleton pattern
    private init() { /* no op */ }

    static let defaultIgnoreTimeInterval = TimeInterval(5)

    /// Used for testing
    internal var ignoreTimeInterval: TimeInterval = CrossAppEventHandler.defaultIgnoreTimeInterval

    /// Send the given event to the event handler.
    ///
    /// Sending event with this API will not invoke the handlers observing the same event with this instance.
    /// - Parameter event: CrossAppEvent instance
    public func send(_ event: CrossAppEvent) {
        // Ignore same event being notified by the observer in this app.
        self.ignoreList.ignoreObservation(of: event, for: self.ignoreTimeInterval)

        // Post the notification
        self.notificationCenter.post(event.notification)
        print( "Posted \(event)")
    }

    /// Register to execute the specified handler when event is received
    /// - Parameters:
    ///   - event: Event to be notified,
    ///   - queue: Queue on which handler to be executed. Defaulted to `DispatchQueue.background`
    ///   - handler: The block that executes when receiving the event
    /// - Returns: An object that can be used for removing observation.
    @discardableResult
    public func on(_ event: CrossAppEvent, queue: DispatchQueue = .background, execute handler: @escaping Handler) -> CrossAppEventObservation {
        let observation = CrossAppEventObservation(event: event, handler: handler, queue: queue)
        if self.observations.add(observation) == false {
            /// Observer to `CrossAppEventNotifier.Center` is not added for this event
            self.addObserverToNotificationCenter(event: event)
        }
        return observation
    }

    /// Remove observation for an event.
    /// - Parameter observation: Observation instance returned as part of registering
    public func remove(observation: CrossAppEventObservation) {

        print( "Removing observation - \(observation)")
        self.observations.remove(observation)
        self.cleanup(observation.event)
    }

    private func addObserverToNotificationCenter(event: CrossAppEvent) {
        print( "Adding observer for \(event)")
        do {
            try self.notificationCenter.observe(event.notification) { darwinNotification in
                let event = darwinNotification.rawValue as String
                guard self.ignoreList.markIgnored(for: event) == false else {
                    print("Ignoring event notification - \(event)")
                    return
                }
                self.observations.executeHandlers(for: event)
            }
        } catch {
            print( "Adding observation failed with \(error.localizedDescription)")
        }
    }


    /// Cleanup the observation for the notification center. Remove observing event that is not required.
    /// - Parameter event: Event that need to be checked
    private func cleanup(_ event: String) {
        // Check if we have more observers for this notification. Else remove observing
        if self.observations.isObserving(event: event) == false {
            print( "Removing notification center observer for \(event)")
            try? self.notificationCenter.removeObservation(event.notification)
        }
    }

    /// Reset all observations & ignore lists.
    /// Used only in test cases right now.
    internal func reset() {
        print( "Resetting observations & ignore lists")
        self.ignoreList.reset()
        self.observations.reset().forEach { self.remove(observation: $0)}
    }
}


