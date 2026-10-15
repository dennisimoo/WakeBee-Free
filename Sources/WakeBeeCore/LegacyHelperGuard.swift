import Foundation
import Darwin

/// The old helper owns a separate recovery journal. Never take over its sleep lease.
public enum LegacyHelperGuard {
    public static let service = "com.awakemac.helper"
    public static let recoveryPath = "/private/var/db/com.awakemac.helper/recovery.json"

    public static func checkResult(exitStatus: Int32, hasRecovery: Bool) throws {
        guard !hasRecovery, exitStatus == 113 else {
            throw exitStatus == 0 || hasRecovery ? Failure.cleanupRequired : Failure.cannotCheck
        }
    }

    public static func ensureReady(checkRecovery: Bool = true) throws {
        for (label, journal) in [(service, recoveryPath),
                ("app.wakebee.helper", "/private/var/db/app.wakebee.helper/recovery.json")] {
            try checkService(label, journal: journal, checkRecovery: checkRecovery)
        }
    }

    private static func checkService(_ label: String, journal: String, checkRecovery: Bool) throws {
        let process = Process(), finished = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "system/\(label)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { _ in finished.signal() }
        try process.run()
        guard finished.wait(timeout: .now() + 3) == .success else {
            process.terminate()
            if finished.wait(timeout: .now() + 1) != .success { kill(process.processIdentifier, SIGKILL) }
            throw Failure.cannotCheck
        }
        try checkResult(exitStatus: process.terminationStatus,
                        hasRecovery: checkRecovery && FileManager.default.fileExists(atPath: journal))
    }

    public enum Failure: LocalizedError {
        case cleanupRequired, cannotCheck
        public var errorDescription: String? {
            switch self {
            case .cleanupRequired:
                "Finish the one-time migration first: in the earlier app, end your session and choose Settings → Closed Lid → Advanced → Remove closed-lid setup. Keep the lid open, quit the earlier app, then try WakeBee setup again."
            case .cannotCheck:
                "WakeBee couldn’t check the earlier closed-lid setup. Keep the lid open and try again."
            }
        }
    }
}
