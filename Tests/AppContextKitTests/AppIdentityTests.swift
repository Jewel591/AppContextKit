import Foundation
import Testing
@testable import AppContextKit

@Test
func fullVersionStringUsesCanonicalFormat() {
    let identity = AppIdentity(
        bundleIdentifier: "com.example.app",
        displayName: "Example",
        marketingVersion: "26.11.0",
        buildNumber: "123"
    )
    #expect(identity.fullVersionString == "26.11.0 (123)")
}

@Test
func currentReadsHostBundleWithoutCrashing() {
    // In the test runner the host bundle has no meaningful version values;
    // this only anchors that missing keys degrade to empty strings.
    let identity = AppIdentity.current(bundle: Bundle(for: BundleAnchor.self))
    #expect(identity.bundleIdentifier.isEmpty == false)
}

private final class BundleAnchor {}
