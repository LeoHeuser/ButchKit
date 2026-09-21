//
//  LogSession.swift
//  ButchKit
//
//  Created by Leo Heuser on 04.08.26.
//

import Foundation

/// A short identifier that ties log messages from different categories into one flow.
///
/// A single user action often crosses several areas of an app. Carrying one identifier through
/// them lets you filter the console for that one run instead of reading each area separately:
///
/// ```swift
/// let session = LogSession()
///
/// Logger.camera.notice("Recording started: session=\(session.id, privacy: .public)")
/// Logger.audio.notice("Audio session activated: session=\(session.id, privacy: .public)")
/// Logger.camera.notice("Recording stopped: session=\(session.id, privacy: .public) duration=\(seconds, privacy: .public)s")
/// ```
///
/// Filtering the console for `session=a3f9` then shows that one run across all categories.
///
/// The identifier has to be interpolated explicitly. `os.Logger` takes a message the compiler
/// assembles at the call site, so nothing can be appended to it afterwards without giving up
/// privacy annotations and lazy formatting. Always write `\(session.id, privacy: .public)`.
public struct LogSession: Sendable {
    /// Four hexadecimal characters. Enough to tell concurrent flows apart within one log,
    /// short enough to stay readable in every message.
    public let id: String

    public init() {
        self.id = String(format: "%04x", UInt16.random(in: .min ... .max))
    }
}
