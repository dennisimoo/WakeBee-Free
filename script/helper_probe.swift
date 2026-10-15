// CI-only read-only XPC client, compiled with HelperProtocol.swift.
import Darwin
import Foundation

@main struct HelperProbe {
    static func main() {
        #if REJECTED
        print("Unapproved build")
        #endif
        guard let requirement = HelperIdentity.helperRequirement else { exit(4) }
        let connection = NSXPCConnection(machServiceName: HelperIdentity.service, options: .privileged)
        connection.setCodeSigningRequirement(requirement)
        connection.remoteObjectInterface = NSXPCInterface(with: WakeBeeHelperProtocol.self)
        connection.resume()
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            fputs("XPC rejected: \(error.localizedDescription)\n", stderr)
            exit(3)
        } as! WakeBeeHelperProtocol
        proxy.checkHealth { success, message in
            print(message)
            exit(success ? 0 : 1)
        }
        RunLoop.current.run(until: Date.now.addingTimeInterval(10))
        exit(2)
    }
}
