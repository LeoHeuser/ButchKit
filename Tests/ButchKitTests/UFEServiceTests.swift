import Foundation
import Testing
@testable import ButchKit

@Suite("UFEService")
struct UFEServiceTests {
    /// `info` must survive in the field, which `Logger.info` does not, and the underlying error
    /// must be identified by its domain and code rather than by its prose description.
    @Test("Logs an info error at notice, with its domain and code")
    func infoIsPersistedWithLogCode() async throws {
        let service = LoggerService(subsystem: "design.heuser.ButchKitTests.UFE.\(UUID().uuidString)")
        let underlying = NSError(domain: "UFETest\(UUID().uuidString.prefix(8))", code: 42)
        let start = Date().addingTimeInterval(-1)

        await MainActor.run {
            UFEService(subsystem: service.subsystem)
                .info(title: "title", message: "message", error: underlying)
        }

        let entry = try #require(
            try await waitForResult {
                try await LogExport.entries(since: start, from: service)
                    .first { $0.message.contains(underlying.logCode) }
            },
            "The UFEService message was not read back from the log store."
        )
        #expect(entry.level == .notice)
    }
}
