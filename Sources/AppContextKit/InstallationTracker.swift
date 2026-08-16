import Foundation

/// Facts about this installation, valid for the current process launch.
///
/// Definitions (fixed across all apps — do not reinterpret per project):
/// - A "launch" is one call to ``InstallationTracker/registerLaunch()``,
///   which the host app makes exactly once per process start.
/// - `launchCount` includes the current launch.
/// - `isFirstLaunchAfterUpdate` is true when the marketing version changed
///   since the previous launch. It is always false on the very first launch.
public struct InstallationFacts: Sendable, Equatable {
    public let firstLaunchDate: Date
    public let launchCount: Int
    public let isFirstLaunch: Bool
    public let isFirstLaunchAfterUpdate: Bool
    /// Marketing version seen on the previous launch, `nil` on first launch.
    public let previousVersion: String?
}

/// Tracks install date, launch count, and version transitions.
///
/// Call ``registerLaunch()`` exactly once per process start (e.g. in the app
/// initializer). Repeated calls in the same process are ignored and return
/// the facts computed by the first call.
@MainActor
public final class InstallationTracker {
    private enum Keys {
        static let firstLaunchDate = "AppContextKit.installation.firstLaunchDate"
        static let launchCount = "AppContextKit.installation.launchCount"
        static let lastLaunchVersion = "AppContextKit.installation.lastLaunchVersion"
    }

    private let userDefaults: UserDefaults
    private let currentVersion: String
    private let now: () -> Date
    private var registeredFacts: InstallationFacts?

    public init(
        userDefaults: UserDefaults = .standard,
        currentVersion: String = AppIdentity.current().marketingVersion,
        now: @escaping () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.currentVersion = currentVersion
        self.now = now
    }

    /// Records the current process launch and returns the facts for it.
    @discardableResult
    public func registerLaunch() -> InstallationFacts {
        if let registeredFacts {
            return registeredFacts
        }

        let previousVersion = userDefaults.string(forKey: Keys.lastLaunchVersion)
        let storedFirstLaunchDate = userDefaults.object(forKey: Keys.firstLaunchDate) as? Date
        let isFirstLaunch = storedFirstLaunchDate == nil

        let firstLaunchDate = storedFirstLaunchDate ?? now()
        if isFirstLaunch {
            userDefaults.set(firstLaunchDate, forKey: Keys.firstLaunchDate)
        }

        let launchCount = userDefaults.integer(forKey: Keys.launchCount) + 1
        userDefaults.set(launchCount, forKey: Keys.launchCount)
        userDefaults.set(currentVersion, forKey: Keys.lastLaunchVersion)

        let facts = InstallationFacts(
            firstLaunchDate: firstLaunchDate,
            launchCount: launchCount,
            isFirstLaunch: isFirstLaunch,
            isFirstLaunchAfterUpdate: !isFirstLaunch
                && previousVersion != nil
                && previousVersion != currentVersion,
            previousVersion: previousVersion
        )
        registeredFacts = facts
        return facts
    }

    /// Facts for the current launch. `nil` until ``registerLaunch()`` runs.
    public var facts: InstallationFacts? {
        registeredFacts
    }
}
