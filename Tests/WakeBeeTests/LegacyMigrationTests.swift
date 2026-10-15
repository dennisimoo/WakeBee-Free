import Foundation
import Testing
import WakeBeeCore
@testable import WakeBee

@Suite @MainActor struct LegacyMigrationTests {
    private func withDefaults(_ body: (UserDefaults, String) throws -> Void) throws {
        let name = "WakeBeeMigrationTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults, name)
    }

    @Test func preferencesImportOnceWithoutOverwritingChoicesOrHelperState() throws {
        try withDefaults { defaults, domain in
            defaults.set(false, forKey: "showTimeInMenuBar")
            let old: [String: Any] = ["showTimeInMenuBar": true, "savedMinutes": 45,
                                     "registeredClosedLidHelperFingerprint": "old", "unknown": "ignored"]
            LegacyMigration.importPreferences(into: defaults, domain: domain, legacy: old)
            #expect(!defaults.bool(forKey: "showTimeInMenuBar"))
            #expect(defaults.integer(forKey: "savedMinutes") == 45)
            #expect(defaults.object(forKey: "registeredClosedLidHelperFingerprint") == nil)
            #expect(defaults.object(forKey: "unknown") == nil)
            defaults.set(60, forKey: "savedMinutes")
            LegacyMigration.importPreferences(into: defaults, domain: domain, legacy: old)
            #expect(defaults.integer(forKey: "savedMinutes") == 60)
        }
    }
}
