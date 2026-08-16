import Foundation

/// Minimum spacing between two runs of a recurring, per-scenario action
/// ("at most once every 24 hours" and the like).
public struct ThrottlePolicy: Sendable, Equatable {
    public let minimumInterval: TimeInterval

    public init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    public static func hours(_ hours: Double) -> ThrottlePolicy {
        ThrottlePolicy(minimumInterval: hours * 3600)
    }

    public static func days(_ days: Double) -> ThrottlePolicy {
        ThrottlePolicy(minimumInterval: days * 86_400)
    }
}

/// A persistent "at most once every N" gate for one scenario.
///
/// Each scenario owns its own `Throttle` instance with a distinct `key`;
/// records never interact across keys. The throttle only answers "is it
/// allowed now" — deciding *whether* to run at all stays with the caller.
///
/// ```swift
/// let paywall = Throttle(key: "launchPaywall", policy: .hours(24))
/// if paywall.isAllowed {
///     showPaywall()
///     paywall.recordRun()
/// }
/// ```
@MainActor
public final class Throttle {
    private let storageKey: String
    private let policy: ThrottlePolicy
    private let userDefaults: UserDefaults
    private let now: () -> Date

    /// - Parameter key: Stable scenario identifier. Renaming it later resets
    ///   the throttle for existing installs.
    public init(
        key: String,
        policy: ThrottlePolicy,
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.storageKey = "AppContextKit.throttle.\(key)"
        self.policy = policy
        self.userDefaults = userDefaults
        self.now = now
    }

    /// Date of the last recorded run, `nil` if it never ran.
    public var lastRunAt: Date? {
        userDefaults.object(forKey: storageKey) as? Date
    }

    /// True when the action never ran, or the minimum interval has elapsed.
    public var isAllowed: Bool {
        guard let lastRunAt else { return true }
        return now().timeIntervalSince(lastRunAt) >= policy.minimumInterval
    }

    /// Marks the action as run now. Call after actually performing it.
    public func recordRun() {
        userDefaults.set(now(), forKey: storageKey)
    }

    /// Forgets the last run, making the next check allowed immediately.
    public func reset() {
        userDefaults.removeObject(forKey: storageKey)
    }
}
