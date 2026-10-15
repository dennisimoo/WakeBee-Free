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
    /// The executing app's exact code identity, including sealed resources.
    public static var currentCodeRequirement: String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var details: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &details) == errSecSuccess,
              let values = details as? [String: Any],
              let hash = values[kSecCodeInfoUnique as String] as? Data, hash.count == 20 else { return nil }
        return "cdhash H\"" + hash.map { String(format: "%02x", $0) }.joined() + "\""
    }
    public static var helperRequirement: String? {
        guard let url = Bundle.main.url(forResource: "helper-requirement", withExtension: "txt"),
              let value = try? String(contentsOf: url, encoding: .utf8),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
