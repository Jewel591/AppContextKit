# AppContextKit

Shared runtime facts and gating mechanisms for all of our apps. Foundation-only, no UI, no third-party dependencies.

It exists so that the same fact ("which version is this", "how many launches", "did it run in the last 24 hours") has exactly one definition across apps and kits, instead of each feature re-reading `Bundle`, re-counting launches, and re-implementing date comparisons.

## What it contains

- **`AppIdentity`** — canonical read of bundle identifier, display name, marketing version, and build number, plus the standard `"1.2.0 (123)"` display form.
- **`InstallationTracker`** — first launch date, launch count, first launch, and first launch after an update. A "launch" is one `registerLaunch()` call, made once per process start.
- **`Throttle`** — persistent "at most once every N hours/days" gate, one instance per scenario. It answers *is it allowed now*; whether to run at all stays with the caller.

## What deliberately stays out

- Subscription/entitlement state — that is RevenueCatKit's domain.
- Login state, network state, and any per-feature policy ("show the paywall every 24h" is an app decision; this kit only supplies the clock math and storage).
- UI of any kind.

## Invariant: zero dependencies, in both directions

This is the load-bearing property of the kit. Agents iterating on it must preserve both halves:

1. **AppContextKit depends on nothing but Foundation.** No third-party packages, no other kits (RevenueCatKit, SupportKit, InAppPromotionKit, CrossPromotionKit, …), no UI frameworks. A feature that needs any of those belongs elsewhere.
2. **No kit depends on AppContextKit.** Kits stay self-contained and receive facts as narrow inputs (a `Date`, an `Int`), mapped by the app's composition layer from `InstallationFacts` / `AppIdentity`. Duplicated *mechanism* inside a kit (its own date math for domain-specific frequency control) is acceptable; what this kit eliminates is duplicated *fact definitions* across apps.

Consequences: this kit can be adopted at project creation time (it is enforced from the MVP stage, earlier than other kits), upgrading it never ripples through the kit dependency graph, and adding a dependency to `Package.swift` is a red flag in review, not a judgment call.

## Requirements

- iOS 17+ / macOS 14+ / visionOS 1+
- Swift 6

## Usage

```swift
import AppContextKit

// At app start, once per process:
let installation = InstallationTracker()
let facts = installation.registerLaunch()

if facts.isFirstLaunchAfterUpdate {
    // e.g. show What's New
}

// Version display, feedback mail metadata, etc.:
let identity = AppIdentity.current()
identity.fullVersionString  // "26.11.0 (123)"

// Per-scenario recurrence gate:
let paywallGate = Throttle(key: "launchPaywall", policy: .hours(24))
if paywallGate.isAllowed && !isPremium {
    showPaywall()
    paywallGate.recordRun()
}
```

All types accept an injected `UserDefaults` and `now` closure for tests.

## Storage keys

Persisted state lives in `UserDefaults` under the `AppContextKit.` prefix:

- `AppContextKit.installation.firstLaunchDate` / `.launchCount` / `.lastLaunchVersion`
- `AppContextKit.throttle.<key>`

Throttle keys are stable identifiers: renaming one resets that throttle for existing installs.

## Agent skill

Integration and migration guidance for agents lives in [`.agents/skills/integrate-appcontextkit/`](.agents/skills/integrate-appcontextkit/SKILL.md), including the legacy UserDefaults key migration required so existing users are not reset to first-launch state.
