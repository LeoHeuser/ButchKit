//
//  LogMirror.swift
//  ButchKit
//
//  Created by Leo Heuser on 04.09.26.
//

import Foundation
import OSLog
import os

/// Keeps this app's persisted log messages across launches.
///
/// The system hands a process only its own log entries, so ``LogExport`` cannot see anything
/// from before the current launch. The mirror closes that gap the only way the platform allows:
/// it reads the process's own entries back and appends the persisted levels — `notice`, `error`
/// and `fault` — to a file in the app container. A relaunch, a background kill and a report sent
/// days later all read from that file.
///
/// ```swift
/// // At the root of the app, once.
/// @State private var logMirror = LogMirror()
///
/// ContentView()
///     .logMirror(logMirror)
///
/// // Wherever diagnostics are shared.
/// @Environment(\.logMirror) private var mirror
/// let url = try await mirror.fileURL(since: .now.addingTimeInterval(-7 * 86_400))
/// ```
///
/// ## When it reads
///
/// Reading the store back costs about a second of CPU regardless of how little is new, so it
/// happens rarely: when the app enters the background (the ``SwiftUICore/View/logMirror(_:)``
/// modifier does this) and at the start of every read here, so a read is always the whole log.
/// The gap this leaves is honest: a crash loses the lines written since the last backgrounding.
/// A crash report from the system covers that moment; the mirror covers everything before it.
///
/// On macOS the scene rarely enters the background and quitting reports no phase at all, so the
/// harvest at the start of a read is the path that matters there.
///
/// ## What the file holds
///
/// The file is JSON Lines, one record per message, capped at ``capacity`` bytes with the oldest
/// lines dropped first. It sits in `Library/Logs/<subsystem>/`, excluded from backup: the log is
/// specific to one device, and values interpolated without a privacy annotation are in it as
/// written. Nothing in the strategy changes because of that — user data is never logged at any
/// level — but it is the reason the file never travels to another device on its own.
///
/// A read taken while the system flushes its buffer can hand back the freshest entry twice. The
/// mirror keeps one copy: two records identical in date, category, level and text within one
/// read are one message, since the store's clock is far finer than any two deliberate messages.
///
/// One mirror per subsystem per process is the intended shape. Two instances on the same file
/// are safe, they take turns through a lock and share what this launch has written, but they
/// read the store twice for the same result.
///
/// ButchKit reserves the category `LogMirror` for its own lines under the app's subsystem, so a
/// harvest that fails is visible in the very log it failed to keep.
public actor LogMirror {
    /// Tells this process's lines from every earlier launch's, per record in the file.
    ///
    /// The store only ever holds the running process, so lines in the file carrying another id
    /// can have nothing in common with what a harvest reads — whatever their dates say. That is
    /// what makes a device clock change between launches harmless.
    nonisolated static let launchID = UUID()

    /// This launch's records that a trim has already dropped from the file.
    ///
    /// Without it a trim would undo itself: the next harvest would find the dropped records
    /// missing from the file and append them again. Process-wide, like the launch id it belongs
    /// to, so two mirrors in one process agree on what was written — it is bookkeeping behind
    /// the launch id, not an access path, and nothing outside this file can reach it.
    private nonisolated static let trimmedRecords = OSAllocatedUnfairLock<[Record: Int]>(initialState: [:])

    /// Where the file lives, and the name inside it. Both read by tests, the first by nobody
    /// else: an app never needs the path, it needs ``fileURL(since:)``.
    public nonisolated let location: URL

    /// The most bytes the file may hold. Older lines go first when it fills.
    public nonisolated let capacity: Int

    /// The subsystem this mirror harvests.
    public nonisolated let service: LoggerService

    private nonisolated let logger: Logger

    /// The harvest running right now, if any. A caller arriving while one runs joins it rather
    /// than paying for a second store read that would find nothing the first did not.
    private var harvestInFlight: Task<Void, any Error>?

    /// Creates a mirror.
    ///
    /// - Parameters:
    ///   - service: The service whose subsystem to keep. Pass the same service you log with; the
    ///     default matches the default logging path, so `LogMirror()` and the environment default
    ///     read the same file.
    ///   - directory: Where to keep the file. Meant for tests; an app takes the default,
    ///     `Library/Logs/<subsystem>/` in its own container.
    ///   - capacity: The most bytes to keep. A million holds months of an app that logs the way
    ///     the strategy asks, at a few dozen lines a day.
    public init(
        service: LoggerService = LoggerService(),
        directory: URL? = nil,
        capacity: Int = 1_000_000
    ) {
        precondition(capacity > 0, "A log mirror needs room for at least one line.")
        self.service = service
        self.capacity = capacity
        self.logger = Logger(subsystem: service.subsystem, category: "LogMirror")

        let directory = directory ?? FileManager.default
            .urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(service.subsystem, isDirectory: true)
        self.location = directory.appendingPathComponent("log.jsonl")
    }

    // MARK: Harvesting

    /// Reads the store and appends whatever the file does not hold yet.
    ///
    /// Safe to call at any time, and idempotent: a second call right after the first finds
    /// nothing new. It still pays the second the store read costs, which is why the
    /// ``SwiftUICore/View/logMirror(_:)`` modifier calls it only on the way to the background.
    /// Callers that overlap share one read: a diagnostics reveal followed by backgrounding is
    /// one second of CPU, not two.
    ///
    /// Cancelling a caller cancels the shared read. The one caller that cancels is the
    /// background hook when the system withdraws its time, and at that point nobody else's
    /// answer is coming either.
    public func harvest() async throws {
        let task: Task<Void, any Error>
        if let running = harvestInFlight {
            task = running
        } else {
            task = Task { try await harvestNow() }
            harvestInFlight = task
        }
        defer { if harvestInFlight == task { harvestInFlight = nil } }

        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func harvestNow() async throws {
        let live = Self.uniqued(
            try await LogExport.readEntries(since: .distantPast, from: service)
                .filter(\.level.isPersisted)
                .map(Record.init)
        )

        try prepareDirectory()
        try withLock {
            var file = try repairedFile()
            let fresh = file.absorbing(live, alreadyTrimmed: Self.trimmedRecords.withLock { $0 })
            guard !fresh.isEmpty else { return }

            try append(fresh, to: &file)
            try trim(&file)
        }
    }

    /// The background hook: harvests while the system still grants time for it.
    ///
    /// On iOS, `performExpiringActivity` is Foundation's way of asking for the seconds an app is
    /// given after it leaves the screen, and unlike UIKit's background tasks it exists in
    /// extensions. The block runs on a thread of the system's choosing and has to stay there
    /// until the work is done, which is what the semaphore is for; if the system calls again to
    /// say time is up, the running harvest is cancelled so the thread is released. On macOS a
    /// process in the background keeps running, so a plain task is all it takes.
    public nonisolated func harvestBeforeSuspension() {
        #if os(macOS)
        Task { await harvestReportingFailure(reason: "background") }
        #else
        let running = OSAllocatedUnfairLock<Task<Void, Never>?>(initialState: nil)

        ProcessInfo.processInfo.performExpiringActivity(withReason: "LogMirror harvest") { expired in
            guard !expired else {
                running.withLock { $0?.cancel() }
                return
            }

            let finished = DispatchSemaphore(value: 0)
            let task = Task {
                defer { finished.signal() }
                await self.harvestReportingFailure(reason: "background")
            }
            running.withLock { $0 = task }
            finished.wait()
        }
        #endif
    }

    // MARK: Reading

    /// Every persisted message since the given date, this launch and every earlier one.
    ///
    /// Harvests first, so the result is never behind the live log. That costs the second a store
    /// read takes; ``LogExport`` costs the same, so plan for a progress state either way.
    ///
    /// - Returns: The matching entries, oldest first, with ``LogEntry/id`` as their position.
    public func entries(since date: Date) async throws -> [LogEntry] {
        await harvestReportingFailure(reason: "read")

        // Under the lock like every writer: a read repairs a damaged tail, and that is a write.
        return try withLock { try repairedFile() }.records
            .filter { $0.date >= date }
            .enumerated()
            .map { offset, record in
                LogEntry(
                    date: record.date,
                    category: record.category,
                    level: record.level,
                    message: record.message,
                    id: offset
                )
            }
    }

    /// The same content as ``entries(since:)``, rendered one line per message, in the format
    /// ``LogExport/text(since:from:)`` uses.
    public func text(since date: Date) async throws -> String {
        LogExport.render(try await entries(since: date))
    }

    /// The same content as ``entries(since:)``, written to a fresh file for a `ShareLink`, named
    /// and placed exactly as ``LogExport/fileURL(since:from:)`` does it. The file is yours to
    /// delete once the share sheet is done.
    ///
    /// - Throws: ``LogExportError/noEntries`` when nothing matched, rather than handing back an
    ///   empty file.
    public func fileURL(since date: Date) async throws -> URL {
        try LogExport.writeFile(try await entries(since: date))
    }

    /// A read that cannot harvest still answers with what the file holds. Losing the whole
    /// history because the live read failed once would be the wrong trade, so the failure goes
    /// into the log instead, where the next harvest picks it up.
    private func harvestReportingFailure(reason: String) async {
        do {
            try await harvest()
        } catch is CancellationError {
            logger.notice("Log mirror harvest cut short: trigger=\(reason, privacy: .public)")
        } catch {
            logger.error("Log mirror harvest failed: trigger=\(reason, privacy: .public) \(error.logCode, privacy: .public)")
        }
    }

    // MARK: The file

    /// One copy of each record a single read handed back more than once.
    ///
    /// At the moment the system flushes its log buffer, a read can return the freshest entry
    /// twice, once from memory and once from disk, and the two are identical to the bit. Dropping
    /// the repeat is safe because the store's clock ticks about every ten microseconds: two
    /// deliberate messages with the same text never share a tick unless a loop logs at a
    /// persisted level, which the strategy forbids. Order is kept; the first copy stays.
    nonisolated static func uniqued(_ records: [Record]) -> [Record] {
        var seen: Set<Record> = []
        return records.filter { seen.insert($0).inserted }
    }

    /// One line of the file. `launch` is what tells this process's lines apart from earlier ones;
    /// the rest is a ``LogEntry`` without the per-read position.
    ///
    /// `Hashable` over every field including the date, which is why the date is stored as the
    /// encoder's default `Double`: it round-trips exactly, and two records only count as the same
    /// message when the store's timestamp agrees to the bit.
    struct Record: Codable, Hashable {
        let launch: UUID
        let date: Date
        let category: String
        let level: LogLevel
        let message: String

        init(_ entry: LogEntry) {
            launch = LogMirror.launchID
            date = entry.date
            category = entry.category
            level = entry.level
            message = entry.message
        }
    }

    /// The decoded file plus the encoded bytes of every line, kept side by side so trimming can
    /// count bytes without encoding twice.
    private struct File {
        var records: [Record] = []
        var lines: [Data] = []

        var byteCount: Int { lines.reduce(0) { $0 + $1.count } }

        /// Which of the live entries the file does not hold yet.
        ///
        /// Subtraction over a multiset rather than a position or a date: the store's timestamps
        /// are coarse enough for a burst to share one, a message that arrived at the daemon late
        /// sits earlier in the store than in the file, and the strategy asks for identical
        /// stems. Counting how often each exact record is already there handles all of that,
        /// and only this launch's records take part — an earlier launch's never overlap with
        /// the store. Records a trim removed count as held, or they would come straight back.
        func absorbing(_ live: [Record], alreadyTrimmed: [Record: Int]) -> [Record] {
            var held = alreadyTrimmed
            for record in records where record.launch == LogMirror.launchID {
                held[record, default: 0] += 1
            }

            return live.filter { record in
                guard let count = held[record], count > 0 else { return true }
                held[record] = count - 1
                return false
            }
        }
    }

    private nonisolated var lockURL: URL {
        location.deletingLastPathComponent().appendingPathComponent("log.lock")
    }

    /// The directory is created on first use and excluded from backup there and then. The
    /// attribute sits on the directory rather than the file because a trim replaces the file,
    /// and a replaced file is a new one as far as attributes are concerned.
    private func prepareDirectory() throws {
        var directory = location.deletingLastPathComponent()
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
    }

    /// Serialises every writer of the file, in this process and any other.
    ///
    /// The lock lives on a separate file whose inode never changes. Locking the log file itself
    /// would break at the first trim: the atomic replace swaps the inode, and a writer already
    /// waiting on the old one would wake up holding a lock on a file nobody reads any more.
    private func withLock<T>(_ body: () throws -> T) throws -> T {
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { close(descriptor) }

        guard flock(descriptor, LOCK_EX) == 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { flock(descriptor, LOCK_UN) }

        return try body()
    }

    /// Reads the file, mending what an interrupted write left behind.
    ///
    /// An append that died halfway leaves a partial last line. It is cut back to the last line
    /// break before anything is added, or the next append would glue itself to the fragment and
    /// take a good line down with it. A line that does not decode for any other reason is
    /// skipped, not fatal: one damaged record is no reason to lose the report.
    private func repairedFile() throws -> File {
        guard let data = try? Data(contentsOf: location) else { return File() }

        var bytes = data
        if let last = bytes.last, last != Self.newline {
            if let cut = bytes.lastIndex(of: Self.newline) {
                bytes = bytes[...cut]
                try bytes.write(to: location, options: .atomic)
            } else {
                bytes = Data()
                try bytes.write(to: location, options: .atomic)
            }
        }

        let decoder = JSONDecoder()
        var file = File()
        for line in bytes.split(separator: Self.newline, omittingEmptySubsequences: true) {
            guard let record = try? decoder.decode(Record.self, from: line) else { continue }
            file.records.append(record)
            file.lines.append(line + [Self.newline])
        }
        return file
    }

    private func append(_ fresh: [Record], to file: inout File) throws {
        let encoder = JSONEncoder()
        var bytes = Data()
        for record in fresh {
            let line = try encoder.encode(record) + [Self.newline]
            bytes.append(line)
            file.records.append(record)
            file.lines.append(line)
        }

        if FileManager.default.fileExists(atPath: location.path) {
            let handle = try FileHandle(forWritingTo: location)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: bytes)
        } else {
            try bytes.write(to: location, options: .atomic)
        }
    }

    /// Drops the oldest lines until the file fits, then rewrites it in one atomic step.
    ///
    /// The newest line is never dropped, so a record larger than the whole capacity still leaves
    /// a file with something in it. Dropped lines of the running launch are remembered, see
    /// `trimmedRecords`.
    private func trim(_ file: inout File) throws {
        guard file.byteCount > capacity else { return }

        var dropped = 0
        var remaining = file.byteCount
        while remaining > capacity, dropped < file.lines.count - 1 {
            remaining -= file.lines[dropped].count
            dropped += 1
        }
        guard dropped > 0 else { return }

        let own = file.records[..<dropped].filter { $0.launch == Self.launchID }
        if !own.isEmpty {
            Self.trimmedRecords.withLock { trimmed in
                for record in own { trimmed[record, default: 0] += 1 }
            }
        }

        file.records.removeFirst(dropped)
        file.lines.removeFirst(dropped)
        try Data(file.lines.joined()).write(to: location, options: .atomic)
    }

    private static let newline = UInt8(ascii: "\n")
}
