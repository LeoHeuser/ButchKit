//
//  LogMirrorTests.swift
//  ButchKit
//
//  Created by Leo Heuser on 04.09.26.
//

import Foundation
import OSLog
import Testing
@testable import ButchKit

@Suite("LogMirror")
struct LogMirrorTests {
    /// A subsystem nothing else logs to, a marker to find the lines by, and a directory of its
    /// own so no test reads another's file.
    private struct Probe {
        let service: LoggerService
        let directory: URL
        let marker = UUID().uuidString

        init(_ name: String) {
            service = LoggerService(subsystem: "design.heuser.ButchKitTests.Mirror.\(name).\(UUID().uuidString)")
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("LogMirrorTests-\(UUID().uuidString)", isDirectory: true)
        }

        func mirror(capacity: Int = 1_000_000) -> LogMirror {
            LogMirror(service: service, directory: directory, capacity: capacity)
        }

        func discard() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    // Every read through the mirror harvests, so `waitForResult` polling the mirror polls the store.

    private func lines(containing marker: String, in mirror: LogMirror) async throws -> [LogEntry] {
        try await mirror.entries(since: .distantPast).filter { $0.message.contains(marker) }
    }

    /// The whole chain once: log, harvest, read back from the file. The second harvest is the
    /// dedupe proving itself — the store hands back every entry of the process every time.
    @Test("Mirrors a message once, however often it harvests")
    func roundTripWithoutDuplicates() async throws {
        let probe = Probe("RoundTrip")
        defer { probe.discard() }
        let mirror = probe.mirror()
        probe.service["RoundTrip"].notice("Mirror round trip: marker=\(probe.marker, privacy: .public)")

        let found = try await waitForResult {
            let found = try await lines(containing: probe.marker, in: mirror)
            return found.isEmpty ? nil : found
        }
        let first = try #require(found?.first, "The marker message was never mirrored.")
        #expect(first.category == "RoundTrip")
        #expect(first.level == .notice)

        try await mirror.harvest()
        try await mirror.harvest()
        #expect(try await lines(containing: probe.marker, in: mirror).count == 1)
    }

    /// `info` does come back from the store for the running process, even though the system
    /// never writes it to disk. The mirror keeps only what the system itself would keep.
    @Test("Keeps notice and above, drops info")
    func persistedLevelsOnly() async throws {
        let probe = Probe("Levels")
        defer { probe.discard() }
        let mirror = probe.mirror()
        probe.service["Levels"].info("Info line: marker=\(probe.marker, privacy: .public)")
        probe.service["Levels"].error("Error line: marker=\(probe.marker, privacy: .public)")

        let found = try await waitForResult {
            let found = try await lines(containing: probe.marker, in: mirror)
            return found.contains { $0.level == .error } ? found : nil
        }
        let entries = try #require(found, "The error line was never mirrored.")
        #expect(entries.allSatisfy { $0.level == .error })
        #expect(!entries.contains { $0.message.hasPrefix("Info line") })
    }

    /// Fill past a small capacity within one launch: the oldest lines go, the newest stays, the
    /// file fits, and a further harvest does not bring the dropped lines back.
    @Test("Trims the oldest lines to capacity and does not re-append them")
    func trimsToCapacity() async throws {
        let probe = Probe("Trim")
        defer { probe.discard() }
        let capacity = 2_000
        let mirror = probe.mirror(capacity: capacity)
        let count = 60
        for n in 0 ..< count {
            probe.service["Trim"].notice("Fill: marker=\(probe.marker, privacy: .public) n=\(n, privacy: .public)")
        }

        let found = try await waitForResult {
            let found = try await lines(containing: probe.marker, in: mirror)
            return found.contains { $0.message.hasSuffix("n=\(count - 1)") } ? found : nil
        }
        let entries = try #require(found, "The newest fill line was never mirrored.")
        #expect(!entries.contains { $0.message.hasSuffix(" n=0") })

        try await mirror.harvest()
        let size = try #require(FileManager.default.attributesOfItem(atPath: mirror.location.path)[.size] as? Int)
        #expect(size <= capacity)
        #expect(!(try await lines(containing: probe.marker, in: mirror)).contains { $0.message.hasSuffix(" n=0") })
    }

    /// A second instance on the same directory is what a relaunch looks like from the file's
    /// point of view: nothing in memory, everything on disk.
    @Test("Hands a new instance what an earlier one wrote")
    func newInstanceReadsEarlierLines() async throws {
        let probe = Probe("Relaunch")
        defer { probe.discard() }
        probe.service["Relaunch"].notice("Before relaunch: marker=\(probe.marker, privacy: .public)")

        let first = probe.mirror()
        let written = try await waitForResult {
            let found = try await lines(containing: probe.marker, in: first)
            return found.isEmpty ? nil : found
        }
        try #require(written != nil, "The marker message was never mirrored.")

        let second = probe.mirror()
        #expect(try await lines(containing: probe.marker, in: second).count == 1)
    }

    /// A file left by an earlier launch whose clock ran ahead. Its dates are later than anything
    /// this process logs, and a cursor keyed on dates would skip every new line forever. The
    /// launch id says the two have nothing in common, so both are kept.
    @Test("Harvests everything after a launch whose lines are dated in the future")
    func foreignLaunchWithFutureDates() async throws {
        let probe = Probe("Clock")
        defer { probe.discard() }
        try FileManager.default.createDirectory(at: probe.directory, withIntermediateDirectories: true)
        let earlier: [String: Any] = [
            "launch": UUID().uuidString,
            "date": Date(timeIntervalSinceNow: 10 * 365 * 86_400).timeIntervalSinceReferenceDate,
            "category": "Clock",
            "level": "notice",
            "message": "Earlier launch: marker=\(probe.marker)"
        ]
        let mirror = probe.mirror()
        var line = try JSONSerialization.data(withJSONObject: earlier)
        line.append(UInt8(ascii: "\n"))
        try line.write(to: mirror.location)

        probe.service["Clock"].notice("This launch: marker=\(probe.marker, privacy: .public)")

        let found = try await waitForResult {
            let found = try await lines(containing: probe.marker, in: mirror)
            return found.count == 2 ? found : nil
        }
        let entries = try #require(found, "Both lines should be in the mirror.")
        #expect(entries.contains { $0.message.hasPrefix("Earlier launch") })
        #expect(entries.contains { $0.message.hasPrefix("This launch") })
    }

    /// Two mirrors, one file, one moment. The lock serialises the writes and the second one to
    /// get in subtracts what the first already appended.
    @Test("Two instances harvesting at once write each line once")
    func concurrentInstances() async throws {
        let probe = Probe("Concurrent")
        defer { probe.discard() }
        probe.service["Concurrent"].notice("Concurrent harvest: marker=\(probe.marker, privacy: .public)")
        let first = probe.mirror()
        let second = probe.mirror()

        let found = try await waitForResult {
            async let one: Void = first.harvest()
            async let two: Void = second.harvest()
            _ = try await (one, two)
            let found = try await lines(containing: probe.marker, in: first)
            return found.isEmpty ? nil : found
        }
        let entries = try #require(found, "The marker message was never mirrored.")
        #expect(entries.count == 1)
    }

    /// The store can hand back the freshest entry twice in one read. Two records identical to
    /// the bit are one message; the same text a millisecond later is another.
    @Test("Keeps one copy of an entry a read handed back twice")
    func uniquedCollapsesExactDuplicates() {
        let date = Date()
        let first = LogEntry(date: date, category: "Same", level: .notice, message: "Same: n=1", id: 0)
        let later = LogEntry(date: date.addingTimeInterval(0.001), category: "Same", level: .notice, message: "Same: n=1", id: 1)

        let unique = LogMirror.uniqued([first, first, later, first].map(LogMirror.Record.init))

        #expect(unique.map(\.date) == [first.date, later.date])
    }

    /// Two callers on one mirror at the same moment share one store read and still leave one
    /// copy of every line.
    @Test("Overlapping harvests on one instance share the work")
    func overlappingHarvestsCoalesce() async throws {
        let probe = Probe("Coalesce")
        defer { probe.discard() }
        probe.service["Coalesce"].notice("Overlapping harvest: marker=\(probe.marker, privacy: .public)")
        let mirror = probe.mirror()

        let found = try await waitForResult {
            async let one: Void = mirror.harvest()
            async let two: Void = mirror.harvest()
            _ = try await (one, two)
            let found = try await lines(containing: probe.marker, in: mirror)
            return found.isEmpty ? nil : found
        }
        let entries = try #require(found, "The marker message was never mirrored.")
        #expect(entries.count == 1)
    }

    /// An append that died halfway leaves a fragment without a line break. It has to go before
    /// the next line is written, or the two would fuse into one unreadable record.
    @Test("Cuts a truncated trailing line before appending")
    func repairsTruncatedTail() async throws {
        let probe = Probe("Repair")
        defer { probe.discard() }
        let mirror = probe.mirror()
        probe.service["Repair"].notice("Before the fragment: marker=\(probe.marker, privacy: .public)")

        let written = try await waitForResult {
            let found = try await lines(containing: probe.marker, in: mirror)
            return found.isEmpty ? nil : found
        }
        try #require(written != nil, "The first message was never mirrored.")

        let handle = try FileHandle(forWritingTo: mirror.location)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"launch":"broken"#.utf8))
        try handle.close()

        probe.service["Repair"].notice("After the fragment: marker=\(probe.marker, privacy: .public)")

        let found = try await waitForResult {
            let found = try await lines(containing: probe.marker, in: mirror)
            return found.count == 2 ? found : nil
        }
        let entries = try #require(found, "Both messages should be in the mirror after the repair.")
        #expect(entries.map(\.message).filter { $0.hasPrefix("Before") }.count == 1)

        let contents = try String(contentsOf: mirror.location, encoding: .utf8)
        #expect(contents.hasSuffix("\n"))
        #expect(!contents.contains(#""launch":"broken"#))
    }
}
