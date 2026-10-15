import WakeBeeCore
import WakeBeeHelperProtocol
import Darwin
import Foundation
import OSLog
import Security

final class HelperHost: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "io.github.dennisimoo.WakeBeeFree.helper.leases")
    let leases = ClosedLidLease(setting: SystemSleepSetting())
    let log = Logger(subsystem: HelperIdentity.service, category: "Recovery")
    var watchdog: DispatchSourceTimer?
    var terminationSources: [DispatchSourceSignal] = []
    let clientRequirement: String
    let clientUID: uid_t
    init(clientRequirement: String, clientUID: uid_t) {
        self.clientRequirement = clientRequirement; self.clientUID = clientUID; super.init()
    }
    func start() {
        queue.sync { do { try leases.recover() } catch { log.error("Recovery failed: \(error.localizedDescription)") } }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1, leeway: .milliseconds(200))
        timer.setEventHandler { [self] in
            guard leases.needsMonitoring else { return }
            do { try leases.tick(now: ProcessInfo.processInfo.systemUptime, power: SystemPowerState.snapshot) }
            catch { log.error("Sleep restoration failed; will retry: \(error.localizedDescription)") }
        }
        timer.resume(); watchdog = timer
        for value in [SIGTERM, SIGINT] {
            signal(value, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: value, queue: queue)
            source.setEventHandler { [self] in
                try? leases.recover()
                exit(0)
            }
            source.resume(); terminationSources.append(source)
        }
    }
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == clientUID else { return false }
        connection.setCodeSigningRequirement(clientRequirement)
        let client = UUID()
        connection.exportedInterface = NSXPCInterface(with: WakeBeeHelperProtocol.self)
        connection.exportedObject = HelperEndpoint(host: self, client: client)
        connection.invalidationHandler = { [self] in
            queue.async {
                do { try self.leases.release(client: client) }
                catch { self.log.error("Disconnected client recovery failed; will retry.") }
            }
        }
        connection.interruptionHandler = connection.invalidationHandler
        connection.resume()
        return true
    }
}
final class HelperEndpoint: NSObject, WakeBeeHelperProtocol, @unchecked Sendable {
    let host: HelperHost
    let client: UUID
    init(host: HelperHost, client: UUID) { self.host = host; self.client = client }
    func checkHealth(reply: @escaping @Sendable (Bool, String) -> Void) {
        host.queue.async {
            do {
                try LegacyHelperGuard.ensureReady()
                _ = try SystemSleepState.readDisabled()
                reply(true, "Helper connected. Ready for closed-lid sessions.")
            } catch { reply(false, error.localizedDescription) }
        }
    }
    func renew(reply: @escaping @Sendable (Bool, String) -> Void) {
        renewWithPolicy(allowsBattery: false, minimumBatteryPercent: 30, maximumBatteryMinutes: 30, reply: reply)
    }
    func renewWithPolicy(allowsBattery: Bool, minimumBatteryPercent: Int, maximumBatteryMinutes: Int,
                         reply: @escaping @Sendable (Bool, String) -> Void) {
        host.queue.async { [self] in
            do {
                try LegacyHelperGuard.ensureReady()
                let policy = try ClosedLidPolicy(allowsBattery: allowsBattery,
                                                minimumBatteryPercent: minimumBatteryPercent,
                                                maximumBatteryMinutes: maximumBatteryMinutes)
                let power = SystemPowerState.snapshot
                try host.leases.renew(client: client, now: ProcessInfo.processInfo.systemUptime, policy: policy, power: power)
                reply(true, power.source == .battery ? "Closed-lid protection is active on battery." : "Closed-lid protection is active on power adapter.")
            } catch {
                if error is LegacyHelperGuard.Failure {
                    do { try host.leases.recover() }
                    catch { reply(false, error.localizedDescription); return }
                }
                // An invalid request must revoke an existing lease as well.
                if error as? ClosedLidStopReason == .invalidPolicy {
                    do { try host.leases.release(client: client) }
                    catch { reply(false, error.localizedDescription); return }
                }
                reply(false, error.localizedDescription)
            }
        }
    }
    func releaseLease(reply: @escaping @Sendable (Bool, String) -> Void) {
        host.queue.async { [self] in
            do {
                try host.leases.release(client: client)
                reply(!host.leases.isApplied, host.leases.isApplied ? "Another WakeBee session is using the helper." : "Normal sleep settings restored")
            }
            catch { reply(false, error.localizedDescription) }
        }
    }
}

// The admin-approved installer owns this configuration. Ad-hoc code is
// authenticated by its exact CodeDirectory hashes, never by an identifier alone.
guard geteuid() == 0 else { exit(77) }
umask(0o077)
if Array(CommandLine.arguments.dropFirst()) == ["--recover-only"] {
    do { try ClosedLidLease(setting: SystemSleepSetting()).recover(); exit(0) }
    catch { fputs("Sleep restoration failed; keep the recovery helper installed.\n", stderr); exit(1) }
}
var info = stat()
guard lstat(HelperIdentity.clientConfiguration, &info) == 0,
      info.st_mode & S_IFMT == S_IFREG, info.st_uid == 0,
      info.st_mode & 0o022 == 0, info.st_nlink == 1,
      let data = try? Data(contentsOf: URL(fileURLWithPath: HelperIdentity.clientConfiguration)),
      let configuration = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
      let requirement = configuration["requirement"] as? String,
      let uid = configuration["uid"] as? UInt32, uid > 0 else {
    fputs("WakeBee Free helper requires a root-owned client configuration.\n", stderr)
    exit(77)
}
var parsed: SecRequirement?
guard SecRequirementCreateWithString(requirement as CFString, [], &parsed) == errSecSuccess else { exit(77) }
let host = HelperHost(clientRequirement: requirement, clientUID: uid)
host.start()
let listener = NSXPCListener(machServiceName: HelperIdentity.service)
listener.delegate = host
listener.resume()
RunLoop.current.run()
