import Foundation

extension NotificationCenter {
    /// Adds a block observer that runs on the main queue, with a handler the
    /// compiler knows is main-actor isolated. Keep the token only when the
    /// observer must be removed before the app quits.
    @discardableResult
    func observeOnMain(
        _ name: Notification.Name,
        object: AnyObject? = nil,
        handler: @escaping @MainActor (Notification) -> Void
    ) -> NSObjectProtocol {
        addObserver(forName: name, object: object, queue: .main) { notification in
            // `queue: .main` already delivers on the main actor, so handing
            // the notification to the handler crosses no isolation boundary.
            nonisolated(unsafe) let notification = notification
            MainActor.assumeIsolated { handler(notification) }
        }
    }
}

extension Timer {
    /// Schedules a repeating timer on the main run loop, with a main-actor
    /// handler. The tolerance is 10% of the interval, the minimum Apple
    /// recommends for a repeating timer, so the system can batch wake-ups.
    @MainActor
    @discardableResult
    static func repeating(every interval: TimeInterval, handler: @escaping @MainActor () -> Void) -> Timer {
        let timer = scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated(handler)
        }
        timer.tolerance = interval * 0.1
        return timer
    }
}
