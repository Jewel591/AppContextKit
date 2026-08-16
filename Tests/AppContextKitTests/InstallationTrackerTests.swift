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
    #expect(facts.currentVersionFirstLaunchDate == installDate)
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

@MainActor
@Test
func currentVersionFirstLaunchDateResetsOnUpdateAndThenSticks() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }

    let installDate = Date(timeIntervalSince1970: 1_000_000)
    InstallationTracker(userDefaults: defaults, currentVersion: "1.0.0", now: { installDate })
        .registerLaunch()

    let updateDate = Date(timeIntervalSince1970: 2_000_000)
    let afterUpdate = InstallationTracker(
        userDefaults: defaults,
        currentVersion: "1.1.0",
        now: { updateDate }
    ).registerLaunch()
    #expect(afterUpdate.currentVersionFirstLaunchDate == updateDate)
    #expect(afterUpdate.firstLaunchDate == installDate)

    let laterDate = Date(timeIntervalSince1970: 3_000_000)
    let laterLaunch = InstallationTracker(
        userDefaults: defaults,
        currentVersion: "1.1.0",
        now: { laterDate }
    ).registerLaunch()
    #expect(laterLaunch.currentVersionFirstLaunchDate == updateDate)
}

@MainActor
@Test
func missingStoredVersionDateIsSeededWithCurrentLaunchDate() throws {
    // Installs that tracked launches before this field existed: same version,
    // but no stored currentVersionFirstLaunchDate.
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }

    let installDate = Date(timeIntervalSince1970: 1_000_000)
    InstallationTracker(userDefaults: defaults, currentVersion: "1.0.0", now: { installDate })
        .registerLaunch()
    defaults.removeObject(forKey: "AppContextKit.installation.currentVersionFirstLaunchDate")

    let seedDate = Date(timeIntervalSince1970: 2_000_000)
    let facts = InstallationTracker(
        userDefaults: defaults,
        currentVersion: "1.0.0",
        now: { seedDate }
    ).registerLaunch()
    #expect(facts.currentVersionFirstLaunchDate == seedDate)
    #expect(!facts.isFirstLaunchAfterUpdate)
}
