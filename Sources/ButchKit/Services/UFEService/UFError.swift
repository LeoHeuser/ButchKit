//
//  UFError.swift
//  ButchKit
//
//  Created by Leo Heuser on 21.05.26.
//

/**
 
 # UFError
 The `UFError` protocol describes any error that can be surfaced through the User-Facing Error Service (`UFEService`).
 Services and views can throw or report values conforming to `UFError`, and the service takes care of logging and presenting a native alert.
 
 The protocol mirrors the native `Error` type but adds the information the UI needs:
 - `titleResource` and `messageResource`, the texts the user reads, from the consuming app's
   `Errors.xcstrings`: everything surfaced through this service is something the user reads after
   something went wrong. Name the table in the resource, so Xcode extracts the key there:
   ```swift
   var titleResource: LocalizedStringResource? { LocalizedStringResource("error.title.sync", table: "Errors") }
   var messageResource: LocalizedStringResource? { LocalizedStringResource("error.message.sync", table: "Errors") }
   ```
 - `title` and `message`, the same texts as keys, for errors written before the resources existed.
   The alert looks them up in `Errors.xcstrings` too, but Xcode extracts a key literal into the
   default table, `Localizable.xcstrings`, where the alert never looks. Prefer the resources.
 - `level` to map the error onto an `os.Logger` level.
 - `error` to optionally carry the underlying technical error for logging.

 Where a resource is set, the alert shows it and ignores the key. Default implementations are
 provided, so a conforming type declares either both resources or both keys, nothing else.

 */

import SwiftUI

public protocol UFError: Error {
    var error: Error? { get }
    /// The title as a key in `Errors.xcstrings`. Prefer `titleResource`, which Xcode extracts into
    /// that table; a key literal here is extracted into `Localizable.xcstrings` instead.
    var title: LocalizedStringKey { get }
    /// The message as a key in `Errors.xcstrings`. Prefer `messageResource`, for the same reason as
    /// `title`.
    var message: LocalizedStringKey { get }
    /// The title, naming its table so Xcode extracts it into `Errors.xcstrings`. Wins over `title`.
    var titleResource: LocalizedStringResource? { get }
    /// The message, naming its table so Xcode extracts it into `Errors.xcstrings`. Wins over
    /// `message`.
    var messageResource: LocalizedStringResource? { get }
    var level: UFErrorLevel { get }
}

public extension UFError {
    var error: Error? { nil }
    var level: UFErrorLevel { .warning }
    var titleResource: LocalizedStringResource? { nil }
    var messageResource: LocalizedStringResource? { nil }
    /// Empty, for an error that sets `titleResource` and so never shows its key. Built from a
    /// string rather than written as a literal, so no empty key is extracted into a catalog.
    var title: LocalizedStringKey { LocalizedStringKey(String()) }
    /// Empty, for an error that sets `messageResource`. See `title`.
    var message: LocalizedStringKey { LocalizedStringKey(String()) }
}

public enum UFErrorLevel: Int, Sendable, CaseIterable {
    case info = 1
    case warning = 2
    case fault = 3
}

struct GenericUFError: UFError, @unchecked Sendable {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let level: UFErrorLevel
    let error: Error?
}
