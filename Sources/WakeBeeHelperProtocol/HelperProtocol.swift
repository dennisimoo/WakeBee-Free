import Foundation
import Security

@objc public protocol WakeBeeHelperProtocol {
    /// Read-only startup check. It never creates or extends a sleep lease.
    func checkHealth(reply: @escaping @Sendable (Bool, String) -> Void)
    // Retained for older signed apps. It always uses adapter-only defaults.
    func renew(reply: @escaping @Sendable (Bool, String) -> Void)
    func renewWithPolicy(allowsBattery: Bool, minimumBatteryPercent: Int, maximumBatteryMinutes: Int,
                         reply: @escaping @Sendable (Bool, String) -> Void)
    func releaseLease(reply: @escaping @Sendable (Bool, String) -> Void)
}

public enum HelperIdentity {
    public static let service = "io.github.dennisimoo.WakeBeeFree.helper"
    public static let plist = "io.github.dennisimoo.WakeBeeFree.helper.plist"
    public static let directory = "/Library/PrivilegedHelperTools/io.github.dennisimoo.WakeBeeFree"
    public static let clientConfiguration = directory + "/client.plist"
    public static var helperRequirement: String? {
        guard let url = Bundle.main.url(forResource: "helper-requirement", withExtension: "txt"),
              let value = try? String(contentsOf: url, encoding: .utf8),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
