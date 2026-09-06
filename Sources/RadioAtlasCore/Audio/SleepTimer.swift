import Foundation

/// A cancelable one-shot timer that runs its expiry callback on the main
/// queue — the sleep-timer behavior behind the player bar's moon menu.
/// Rescheduling replaces any pending timer.
public final class SleepTimer {
    /// The scheduled expiry (nil when inactive) — exposed so the UI can
    /// render a live countdown.
    public private(set) var fireDate: Date?

    private var workItem: DispatchWorkItem?

    public init() {}

    public var isActive: Bool { fireDate != nil }

    /// Schedules (replacing any pending timer) a fire `seconds` from now.
    /// The callback runs on the main queue; `fireDate` is cleared first.
    public func schedule(seconds: TimeInterval, onExpire: @escaping () -> Void) {
        cancel()
        fireDate = Date().addingTimeInterval(seconds)
        let item = DispatchWorkItem { [weak self] in
            self?.fireDate = nil
            self?.workItem = nil
            onExpire()
        }
        workItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: item)
    }

    /// Cancels any pending timer. Safe to call when inactive.
    public func cancel() {
        workItem?.cancel()
        workItem = nil
        fireDate = nil
    }
}
