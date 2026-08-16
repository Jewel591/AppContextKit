import Foundation
import Testing
@testable import AppContextKit

private func makeDefaults() throws -> (UserDefaults, cleanup: () -> Void) {
    let suiteName = "AppContextKitTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    return (defaults, { defaults.removePersistentDomain(forName: suiteName) })
}

@MainActor
@Test
func firstEverLaunchIsRecordedAsFirstLaunch() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }

    let installDate = Date(timeIntervalSince1970: 1_000_000)
    let tracker = InstallationTracker(
        userDefaults: defaults,
        currentVersion: "1.0.0",
        now: { installDate }
    )

    let facts = tracker.registerLaunch()
    #expect(facts.isFirstLaunch)
    #expect(!facts.isFirstLaunchAfterUpdate)
    #expect(facts.launchCount == 1)
    #expect(facts.firstLaunchDate == installDate)
    #expect(facts.previousVersion == nil)
}

@MainActor
@Test
func repeatedRegisterInSameProcessIsIdempotent() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }

    let tracker = InstallationTracker(
        userDefaults: defaults,
        currentVersion: "1.0.0",
        now: { Date(timeIntervalSince1970: 1_000_000) }
    )

    let first = tracker.registerLaunch()
    let second = tracker.registerLaunch()
    #expect(first == second)
    #expect(second.launchCount == 1)
}

@MainActor
@Test
func launchCountAccumulatesAcrossProcessLaunches() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }

    let installDate = Date(timeIntervalSince1970: 1_000_000)
    for expectedCount in 1...3 {
        let tracker = InstallationTracker(
            userDefaults: defaults,
            currentVersion: "1.0.0",
            now: { installDate }
        )
        let facts = tracker.registerLaunch()
        #expect(facts.launchCount == expectedCount)
        #expect(facts.isFirstLaunch == (expectedCount == 1))
        #expect(facts.firstLaunchDate == installDate)
    }
}

@MainActor
@Test
func versionChangeIsReportedOnceAsFirstLaunchAfterUpdate() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }

    let now = { Date(timeIntervalSince1970: 1_000_000) }

    InstallationTracker(userDefaults: defaults, currentVersion: "1.0.0", now: now)
        .registerLaunch()

    let afterUpdate = InstallationTracker(
        userDefaults: defaults,
        currentVersion: "1.1.0",
        now: now
    ).registerLaunch()
    #expect(afterUpdate.isFirstLaunchAfterUpdate)
    #expect(afterUpdate.previousVersion == "1.0.0")

    let nextLaunch = InstallationTracker(
        userDefaults: defaults,
        currentVersion: "1.1.0",
        now: now
    ).registerLaunch()
    #expect(!nextLaunch.isFirstLaunchAfterUpdate)
    #expect(nextLaunch.previousVersion == "1.1.0")
}
