import Foundation
import WakeBeeCore

/// Old identifiers are read only for the one-time migration, never used for new state.
@MainActor enum LegacyMigration {
    static let appID = "com.awakemac.AwakeMac"
    static let preferenceKeys = [
        "rememberDuration", "savedMinutes", "showTimeInMenuBar", "keepDisplayAwake",
        "allowClosedLidOnBattery", "closedLidBatteryCutoff", "closedLidBatteryMinutes",
        "endSessionOnLowBattery", "requirePowerAdapter", "SUEnableAutomaticChecks"
    ]

    static func importPreferences(into defaults: UserDefaults = .standard,
                                  domain: String = "io.github.dennisimoo.WakeBeeFree",
                                  legacy: [String: Any]? = nil) {
        let marker = "wakeBeePreferencesMigrated"
        guard !defaults.bool(forKey: marker) else { return }
        let previous = legacy ?? defaults.persistentDomain(forName: appID) ?? [:]
        let current = defaults.persistentDomain(forName: domain) ?? [:]
        for key in preferenceKeys where current[key] == nil {
            if let value = previous[key] { defaults.set(value, forKey: key) }
        }
        // Do not copy helper fingerprints, login-item approvals, active sessions, or update caches.
        defaults.set(true, forKey: marker)
    }
}
