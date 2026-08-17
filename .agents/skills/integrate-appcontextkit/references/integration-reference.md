# AppContextKit integration reference

Names below come from real apps in the product matrix. Verify against the target app's current source before relying on them — apps evolve after this reference is written.

## Storage key layout (Kit-owned)

| Key | Type | Written by |
|---|---|---|
| `AppContextKit.installation.firstLaunchDate` | `Date` | first `registerLaunch()` ever (or one-time migration seed) |
| `AppContextKit.installation.launchCount` | `Int` | every `registerLaunch()` |
| `AppContextKit.installation.lastLaunchVersion` | `String` | every `registerLaunch()` |
| `AppContextKit.installation.currentVersionFirstLaunchDate` | `Date` | first `registerLaunch()` on each new version (also seeded once on installs that predate the field) |
| `AppContextKit.throttle.<key>` | `Date` | `Throttle.recordRun()` for scenario `<key>` |

Never write these keys directly outside the one-time legacy migration described below.

## Composition-level setup

```swift
import AppContextKit

@main
struct MyApp: App {
    private let installationTracker: AppContextKit.InstallationTracker

    init() {
        Self.migrateLegacyContextKeysIfNeeded()   // must run before registerLaunch()
        installationTracker = AppContextKit.InstallationTracker()
        installationTracker.registerLaunch()
    }
    // ...
}
```

`registerLaunch()` runs exactly once per process start. Repeated calls in the same process are ignored and return the first call's facts, but do not rely on that as a design — keep a single call site.

## Legacy-key migration

### Why it is mandatory

On an existing install, the Kit's keys are empty. Without seeding, the first `registerLaunch()` after the update reports `isFirstLaunch == true` and a fresh `firstLaunchDate`, so long-time users re-enter onboarding, first-launch paywalls, and "new user" windows. Seed **before** the first `registerLaunch()`, guarded so it runs at most once.

### Seeding pattern

```swift
private static func migrateLegacyContextKeysIfNeeded() {
    let defaults = UserDefaults.standard
    let kitFirstLaunchKey = "AppContextKit.installation.firstLaunchDate"
    guard defaults.object(forKey: kitFirstLaunchKey) == nil else { return }

    // Earliest known install date wins. List every legacy key this app ever used.
    let legacyDates = [
        defaults.object(forKey: "appFirstLaunchDateV1") as? Date,           // example: CodeCat
        defaults.object(forKey: "reviewPrompt_firstLaunchDate") as? Date,   // example: MONO / Apper
    ].compactMap { $0 }

    if let earliest = legacyDates.min() {
        defaults.set(earliest, forKey: kitFirstLaunchKey)
    }
    // If no legacy date exists this really is (indistinguishable from) a fresh
    // install; let registerLaunch() establish the date normally.
}
```

Notes:

- Launch count has no reliable legacy source in most apps; starting it at 0 for existing users is accepted. If the app kept a trustworthy counter, seed `AppContextKit.installation.launchCount` the same way.
- On the migration launch, `previousVersion` is `nil`, so `isFirstLaunchAfterUpdate` is `false` even though the user did just update. Accepted one-time inaccuracy; do not fake `lastLaunchVersion` to compensate unless the app stored the previous version under a legacy key you can trust.
- Keep legacy key string literals only inside the migration function. Delete the types and constants that owned them.
- Leave a legacy key's stored value in place if another subsystem still reads it (e.g. a review-prompt manager that keeps its own domain keys); copying is not stealing.

### Known legacy keys per app (as of 2026-08-17)

| App | Legacy key | Meaning | Migration |
|---|---|---|---|
| CodeCat | `appFirstLaunchDateV1` (`AppInstallTracker`) | install date | seed `installation.firstLaunchDate`, then delete `AppInstallTracker` |
| MONO / Apper / CodeCat / Supamate | `reviewPrompt_firstLaunchDate` | install date proxy inside review-prompt domain | usable as a seeding source; the key itself stays with the review-prompt domain |
| MONO | `launchMarketingAdLastShownDateV2` (`LaunchPaywallManager`) | last paywall shown | seed `AppContextKit.throttle.launchPaywall` with the stored date |
| MONO / CodeCat / Filmo | `NextUpdateRemindDate` / `IgnoredAppVersion` | AppUpdateKit snooze / skip | **stay with AppUpdateKit** (it writes these exact legacy names). Do not seed them into `Throttle` — a remind-later date is a future snooze, not a last-run timestamp |
| MONO / Apper / CodeCat / Supamate | `reviewPrompt_appSessionCount`, `reviewPrompt_successfulActionCount`, `reviewPrompt_lastReviewPromptDate`, `reviewPrompt_pendingReviewRequest`, … | review-prompt domain counters | stay in the review-prompt domain; map them through `ReviewPromptStorageKeys` when adopting ReviewKit. Do not copy them into AppContextKit |
| LastTime | *(none)* | no pre-kit first-launch / review keys | 2026-08-16 migration established new keys; existing installs start install-age and review counts from that build |

## Replacing version reads

Before:

```swift
let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
Text("v\(version) (\(build))")
```

After:

```swift
let identity = AppIdentity.current()
Text("v\(identity.marketingVersion) (\(identity.buildNumber))")
// or the canonical combined form:
Text(identity.fullVersionString)   // "1.2.0 (45)"
```

## Replacing hand-written throttles

Before (typical pattern found in shipped apps):

```swift
if let last = UserDefaults.standard.object(forKey: "lastPaywallDate") as? Date,
   Date().timeIntervalSince(last) < 24 * 60 * 60 {
    return
}
showPaywall()
UserDefaults.standard.set(Date(), forKey: "lastPaywallDate")
```

After:

```swift
let paywallThrottle = Throttle(key: "launchPaywall", policy: .hours(24))
if paywallThrottle.isAllowed {
    showPaywall()
    paywallThrottle.recordRun()   // only after the action actually happened
}
```

One scenario per instance and per key. Suggested key style: lowerCamelCase scenario names (`launchPaywall`, `updateCheck`, `crossPromoRotation`). The Kit prefixes them to `AppContextKit.throttle.<key>` internally.

## Testing consumers

```swift
let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
var currentDate = Date(timeIntervalSince1970: 1_000_000)

let tracker = InstallationTracker(
    userDefaults: suite,
    currentVersion: "2.0.0",
    now: { currentDate }
)
let throttle = Throttle(
    key: "scenario",
    policy: .hours(24),
    userDefaults: suite,
    now: { currentDate }
)
```

Advance `currentDate` to simulate time passing. Never use `.standard` or real `Date()` in tests.
