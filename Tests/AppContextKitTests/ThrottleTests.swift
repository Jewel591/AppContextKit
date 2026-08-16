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
func throttleAllowsFirstRunThenBlocksUntilIntervalElapses() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }

    var currentDate = Date(timeIntervalSince1970: 1_000_000)
    let throttle = Throttle(
        key: "paywall",
        policy: .hours(24),
        userDefaults: defaults,
        now: { currentDate }
    )

    #expect(throttle.isAllowed)
    throttle.recordRun()
    #expect(!throttle.isAllowed)

    currentDate = currentDate.addingTimeInterval(23 * 3600)
    #expect(!throttle.isAllowed)

    currentDate = currentDate.addingTimeInterval(2 * 3600)
    #expect(throttle.isAllowed)
}

@MainActor
@Test
func throttleKeysAreIndependentScenarios() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }

    let date = Date(timeIntervalSince1970: 1_000_000)
    let paywall = Throttle(key: "paywall", policy: .hours(24), userDefaults: defaults, now: { date })
    let review = Throttle(key: "review", policy: .days(7), userDefaults: defaults, now: { date })

    paywall.recordRun()
    #expect(!paywall.isAllowed)
    #expect(review.isAllowed)
}

@MainActor
@Test
func throttleResetAllowsImmediately() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }

    let date = Date(timeIntervalSince1970: 1_000_000)
    let throttle = Throttle(key: "dedup", policy: .hours(24), userDefaults: defaults, now: { date })

    throttle.recordRun()
    #expect(!throttle.isAllowed)
    #expect(throttle.lastRunAt == date)

    throttle.reset()
    #expect(throttle.isAllowed)
    #expect(throttle.lastRunAt == nil)
}

@MainActor
@Test
func throttleStatePersistsAcrossInstances() throws {
    let (defaults, cleanup) = try makeDefaults()
    defer { cleanup() }

    let date = Date(timeIntervalSince1970: 1_000_000)
    Throttle(key: "paywall", policy: .hours(24), userDefaults: defaults, now: { date })
        .recordRun()

    let relaunched = Throttle(key: "paywall", policy: .hours(24), userDefaults: defaults, now: { date })
    #expect(!relaunched.isAllowed)
    #expect(relaunched.lastRunAt == date)
}
