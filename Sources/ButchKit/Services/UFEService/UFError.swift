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
 - `title` and `message` as `LocalizedStringKey` so strings live in the consuming app's catalog. Both
   resolve in `Errors.xcstrings`: the alert renders them with `Text(error:)`, because everything
   surfaced through this service is something the user reads after something went wrong.
 - `level` to map the error onto an `os.Logger` level.
 - `error` to optionally carry the underlying technical error for logging.
 
 Default implementations are provided so a conforming type only has to declare `title` and `message`.
 
 */

import SwiftUI

public protocol UFError: Error {
    var error: Error? { get }
    var title: LocalizedStringKey { get }
    var message: LocalizedStringKey { get }
    var level: UFErrorLevel { get }
}

public extension UFError {
    var error: Error? { nil }
    var level: UFErrorLevel { .warning }
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
