import Foundation
import OSLog
import Testing
@testable import ButchKit

@Suite("LoggerService")
struct LoggerServiceTests {
    @Test("Resolves a non-empty subsystem by default")
    func defaultSubsystem() {
        #expect(!LoggerService().subsystem.isEmpty)
    }

    @Test("Uses an explicit subsystem when given one")
    func explicitSubsystem() {
        #expect(LoggerService(subsystem: "design.heuser.Test").subsystem == "design.heuser.Test")
    }

    /// Two default services must be interchangeable. The environment default and every
    /// `LogExport` default argument construct their own, and an export that resolved a different
    /// subsystem than the loggers did would come back empty with nothing to warn about it.
    @Test("Makes every default service equal to every other")
    func defaultServicesAreInterchangeable() {
        #expect(LoggerService() == LoggerService())
        #expect(LoggerService().subsystem == LoggerService(subsystem: nil).subsystem)
    }
}

@Suite("LogCategory")
struct LogCategoryTests {
    @Test("Takes its name from a string literal")
    func stringLiteral() {
        let category: LogCategory = "Camera"
        #expect(category.name == "Camera")
        #expect(category == LogCategory("Camera"))
        #expect(category != LogCategory("Audio"))
    }
}

@Suite("LogSession")
struct LogSessionTests {
    @Test("Produces a four-character hexadecimal identifier")
    func identifierShape() {
        let id = LogSession().id
        #expect(id.count == 4)
        #expect(id.allSatisfy { $0.isHexDigit })
    }

    @Test("Produces differing identifiers")
    func identifiersDiffer() {
        let ids = Set((0 ..< 20).map { _ in LogSession().id })
        #expect(ids.count > 1)
    }
}

@Suite("LogExport")
struct LogExportTests {
    /// Everything a test needs to write into a subsystem nothing else touches and read it back.
    private struct Probe {
        let service: LoggerService
        let marker = UUID().uuidString
        let start = Date().addingTimeInterval(-1)

        init(_ name: String) {
            service = LoggerService(subsystem: "design.heuser.ButchKitTests.\(name).\(UUID().uuidString)")
        }
    }

    /// Writes a marker message and reads it back. This is the only test that proves the whole
    /// `OSLogStore` chain — scope, position, predicate and mapping — actually works.
    @Test("Reads back a message it just wrote")
    func roundTrip() async throws {
        let probe = Probe("Export")
        probe.service["RoundTrip"].notice("Export round trip: marker=\(probe.marker, privacy: .public)")

        let match = try await waitForResult {
            try await LogExport.entries(since: probe.start, from: probe.service)
                .first { $0.message.contains(probe.marker) }
        }

        let found = try #require(match, "The marker message was not read back from the log store.")
        #expect(found.category == "RoundTrip")
        #expect(found.level == .notice)
    }

    /// `Logger` exposes neither its subsystem nor its category, so writing a message and reading it
    /// back is the only way to prove `Logger(category:subsystem:)` files it where it claims to.
    @Test("Files a logger built from a category in that subsystem and category")
    func loggerCategoryInit() async throws {
        let probe = Probe("Init")
        Logger(category: "Init", subsystem: probe.service.subsystem)
            .notice("Logger init: marker=\(probe.marker, privacy: .public)")

        let match = try await waitForResult {
            try await LogExport.entries(since: probe.start, from: probe.service)
                .first { $0.message.contains(probe.marker) }
        }

        let found = try #require(match, "The marker message was not read back from the log store.")
        #expect(found.category == "Init")
    }

    @Test("Renders entries as one line each")
    func textRendering() async throws {
        let probe = Probe("Text")
        probe.service["Rendering"].notice("Text rendering: marker=\(probe.marker, privacy: .public)")

        let found = try #require(
            try await waitForResult { try await line(containing: probe.marker, probe) },
            "The marker message was not present in the rendered text."
        )
        #expect(found.contains("[notice]"))
        #expect(found.contains("[Rendering]"))
    }

    /// Both cases go through the same `split`/`joined` in `render`: a plain break, and a blank line
    /// that an earlier version silently dropped.
    @Test("Keeps line breaks inside a message on one escaped line", arguments: [
        ("first\nsecond", #"first\nsecond"#),
        ("header\n\nfooter", #"header\n\nfooter"#)
    ])
    func flattensNewlines(body: String, expected: String) async throws {
        let probe = Probe("Newline")
        probe.service["Newline"].notice("Multi line: marker=\(probe.marker, privacy: .public) body=\(body, privacy: .public)")

        let found = try #require(
            try await waitForResult { try await line(containing: probe.marker, probe) },
            "The marker message was not present in the rendered text."
        )
        #expect(found.contains(expected))
    }

    private func line(containing marker: String, _ probe: Probe) async throws -> Substring? {
        try await LogExport.text(since: probe.start, from: probe.service)
            .split(separator: "\n")
            .first { $0.contains(marker) }
    }

    @Test("Writes a readable text file the share sheet can attach")
    func writesFile() async throws {
        let probe = Probe("File")
        probe.service["File"].notice("File export: marker=\(probe.marker, privacy: .public)")

        let url = try await waitForResult { () -> URL? in
            let url = try await LogExport.fileURL(since: probe.start, from: probe.service)
            let contents = try String(contentsOf: url, encoding: .utf8)
            guard contents.contains(probe.marker) else {
                try? FileManager.default.removeItem(at: url)
                return nil
            }
            return url
        }

        let file = try #require(url, "The marker message never reached the exported file.")
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(file.pathExtension == "txt")
        #expect(FileManager.default.fileExists(atPath: file.path))

        // <AppName>-Diagnostics-<date>-<time>-<id>.txt, with the app name taken from the bundle.
        let name = file.lastPathComponent
        #expect(name.contains("-Diagnostics-"))
        let appName = try #require(name.components(separatedBy: "-Diagnostics-").first)
        #expect(!appName.isEmpty)
        #expect(appName.allSatisfy { $0.isLetter || $0.isNumber })
    }

    @Test("Gives every export its own file")
    func fileNamesAreUnique() async throws {
        let probe = Probe("Unique")
        probe.service["Unique"].notice("Unique file: marker=\(probe.marker, privacy: .public)")

        let pair = try await waitForResult { () -> (URL, URL)? in
            guard let first = try? await LogExport.fileURL(since: probe.start, from: probe.service),
                  let second = try? await LogExport.fileURL(since: probe.start, from: probe.service)
            else { return nil }
            return (first, second)
        }

        let (first, second) = try #require(pair, "The export never produced a file.")
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: second)
        }

        #expect(first != second)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test("Refuses to write a file when nothing matched")
    func emptyExportThrows() async throws {
        // A subsystem nothing ever logs to: the export has to say so, not hand back an empty file.
        let probe = Probe("Empty")

        await #expect(throws: LogExportError.noEntries) {
            try await LogExport.fileURL(since: probe.start, from: probe.service)
        }
    }

    @Test("Keeps identities unique when the same message repeats")
    func repeatedMessagesStayDistinct() async throws {
        let probe = Probe("Repeat")
        let count = 200

        // A constant stem is exactly what the strategy asks for, so repeats are the normal case.
        for _ in 0 ..< count {
            probe.service["Repeat"].notice("Repeated message: marker=\(probe.marker, privacy: .public)")
        }

        let entries = try await waitForResult { () -> [LogEntry]? in
            let found = try await LogExport.entries(since: probe.start, from: probe.service)
                .filter { $0.message.contains(probe.marker) }
            return found.count == count ? found : nil
        }

        let found = try #require(entries, "Not every repeated message came back.")
        #expect(Set(found.map(\.id)).count == found.count)

        // Reading the same window again yields the same identities, so a List can diff. This also
        // covers the single-entry case, so there is no separate stability test.
        let again = try await LogExport.entries(since: probe.start, from: probe.service)
            .filter { $0.message.contains(probe.marker) }
        #expect(again.map(\.id) == found.map(\.id))
    }

    /// The store ignores the requested position for the current-process scope and hands back
    /// every entry of the process, so the date has to be applied in code. A window that starts
    /// after the message was written must not contain it.
    @Test("Leaves out messages written before the window")
    func sinceFiltersByDate() async throws {
        let probe = Probe("Since")
        probe.service["Since"].notice("Before the window: marker=\(probe.marker, privacy: .public)")

        let match = try await waitForResult {
            try await LogExport.entries(since: probe.start, from: probe.service)
                .first { $0.message.contains(probe.marker) }
        }
        try #require(match != nil, "The marker message was not read back from the log store.")

        let later = try await LogExport.entries(since: Date().addingTimeInterval(60), from: probe.service)
        #expect(!later.contains { $0.message.contains(probe.marker) })
    }
}
