import Foundation

/// The single source of truth for "which app is this, at which version".
///
/// Every kit and feature that needs the marketing version, build number, or
/// bundle identifier should read it from here instead of parsing
/// `Bundle.main.infoDictionary` on its own.
public struct AppIdentity: Sendable, Equatable {
    public let bundleIdentifier: String
    public let displayName: String
    /// `CFBundleShortVersionString`, e.g. `"26.11.0"`.
    public let marketingVersion: String
    /// `CFBundleVersion`, e.g. `"123"`.
    public let buildNumber: String

    /// Canonical display form: `"26.11.0 (123)"`.
    public var fullVersionString: String {
        "\(marketingVersion) (\(buildNumber))"
    }

    public init(
        bundleIdentifier: String,
        displayName: String,
        marketingVersion: String,
        buildNumber: String
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.marketingVersion = marketingVersion
        self.buildNumber = buildNumber
    }

    /// Reads the identity of the host app from the given bundle.
    public static func current(bundle: Bundle = .main) -> AppIdentity {
        let info = bundle.infoDictionary ?? [:]
        let displayName =
            (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? ""
        return AppIdentity(
            bundleIdentifier: bundle.bundleIdentifier ?? "",
            displayName: displayName,
            marketingVersion: info["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: info["CFBundleVersion"] as? String ?? ""
        )
    }
}
