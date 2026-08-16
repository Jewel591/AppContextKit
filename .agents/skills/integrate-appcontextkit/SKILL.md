---
name: integrate-appcontextkit
description: Integrate, migrate, review, or troubleshoot an Apple app that uses the AppContextKit Swift package. Use when adding AppContextKit to a Swift/SwiftUI app, replacing app-local install trackers, launch counters, first-launch flags, version reads, or hand-written "at most once every N hours" throttles, migrating legacy UserDefaults keys so existing users are not reset to first-launch state, or auditing that runtime facts come from one source.
---

# Integrate AppContextKit

Use AppContextKit as the app's only source for installation facts (first launch date, launch count, first launch, first launch after update), app identity (bundle ID, display name, marketing version, build number), and per-scenario run throttling. Keep every decision about *what* to show and *when* in the host app; the Kit only reports facts and answers "is it allowed now".

## Read the local contract

Read the package `README.md` and the current public declarations under `Sources/AppContextKit/` before changing an app. Do not reconstruct API names from memory. The doc comments on `InstallationTracker` and `Throttle` are the authoritative definitions of "launch" and throttle semantics — do not reinterpret them per project.

Read [references/integration-reference.md](references/integration-reference.md) when writing new integration code or migrating an existing app. It contains the storage key layout, known legacy keys per app, and migration snippets. Adapt names to the target app instead of copying another app's identifiers.

Also read and obey the target repository's `AGENTS.md` / `CLAUDE.md` or equivalent instructions.

## Follow this workflow

1. Inspect the app for existing implementations the Kit replaces: app-local install/first-launch trackers, launch or session counters, `Bundle.main` version/build reads scattered across views and view models, and hand-written date-comparison throttles ("show at most once every 24 hours"). List each with its UserDefaults keys before writing any code.
2. Add the `AppContextKit` package dependency (`https://github.com/Jewel591/AppContextKit`, up-to-next-major from the latest release) and the `AppContextKit` product to the app target. Extension targets (widgets, Live Activities) get the product only if they actually read installation facts.
3. Plan legacy-key migration **before** the first `registerLaunch()` ever runs on an existing install. If the app previously stored a first-launch/install date under its own key, seed `AppContextKit.installation.firstLaunchDate` from it one time; otherwise every existing user is treated as a fresh install, which re-triggers onboarding, first-launch paywalls, and "new user" gating. See the reference for the exact seeding order and known per-app legacy keys.
4. Construct one `AppContextKit.InstallationTracker()` at app composition level and call `registerLaunch()` exactly once per process start (app initializer or first scene setup). A "launch" is one process start — not one foregrounding. Do not call it from `scenePhase` changes or `onAppear`.
5. Replace scattered `Bundle.main.infoDictionary` version/build reads with `AppIdentity.current()`. Use `fullVersionString` for user-facing "1.2.0 (45)" style display so all apps format it identically.
6. Replace each hand-written throttle with its own `Throttle` instance. One scenario = one instance = one stable key (`launchPaywall`, `updateCheck`, …). Renaming a key later resets the throttle for existing installs, so choose the key deliberately and seed it from the legacy last-shown date where one exists. Only call `recordRun()` after the action actually happened, not when it was merely allowed.
7. Keep domain policy out of the Kit's scope. Review-prompt eligibility, paywall display rules, and campaign selection stay in the app (or their own Kit); they *consume* `InstallationFacts` and `Throttle` as inputs. Do not add domain counters to AppContextKit storage keys.
8. Delete the replaced app-local code in the same change: the old tracker type, the old counters, the old throttle date-math, and their key constants (keep the key string literals only inside the one-time migration). Two parallel tracking systems are worse than either alone.
9. Build and run the smallest relevant tests. When testing code that consumes the Kit, inject a dedicated `UserDefaults(suiteName:)` and a fixed `now` closure; never test against `.standard` or real time.
10. Verify against the lint: `app-context-kit-lint` (product-playbook) requires the SPM dependency, a production `import AppContextKit`, a module-qualified `AppContextKit.InstallationTracker(...)` construction, and a `.registerLaunch()` call in the app target. Passing the lint is necessary but not sufficient — the migration steps above are what the lint cannot check.

## Preserve these boundaries

- `InstallationFacts` answers what is true about this install; it never decides what to show.
- `Throttle` answers whether enough time has passed for one named scenario; whether to run at all stays with the caller.
- `AppIdentity` is the only reader of bundle identity/version in app code.
- Domain policy (ratings, paywalls, campaigns) lives in the app or its own Kit and receives facts as narrow inputs; Kits do not depend on AppContextKit.
- Storage keys under the `AppContextKit.` prefix belong to the Kit. Never write them directly outside the one-time legacy migration.

## Review the result

Before declaring the integration complete, search the whole app for leftover direct reads the Kit now owns: `CFBundleShortVersionString` / `CFBundleVersion` outside `AppIdentity` call sites, surviving first-launch/install-date keys being written, and date-comparison throttle logic. Confirm `registerLaunch()` cannot run more than once per process and cannot run before the legacy seeding. Confirm an existing user upgrading to this build keeps their original first-launch date and does not see first-launch-only UI again. State explicitly which legacy UserDefaults keys were migrated, which were left in place for other consumers, and which were deleted.
