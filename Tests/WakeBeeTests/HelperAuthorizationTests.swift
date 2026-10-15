import Foundation
import Testing
@testable import WakeBee

@Suite struct HelperAuthorizationTests {
    @Test func shellQuotingKeepsPathsLiteral() throws {
        let value = "/tmp/a 'quoted' path; $(touch /tmp/never)\n`id`"
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "printf %s " + SystemHelperRegistration.shellQuote(value)]
        process.standardOutput = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(String(decoding: output, as: UTF8.self) == value)
    }
}
