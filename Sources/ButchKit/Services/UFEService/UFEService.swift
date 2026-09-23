//
//  UFEService.swift
//  ButchKit
//
//  Created by Leo Heuser on 21.05.26.
//

/**
 
 # UFEService
 The `UFEService` (User-Facing Error Service) is an `@Observable` service that collects errors from anywhere in an app and surfaces them through a single native alert.
 
 Integrate it once on the root view:
 ```swift
 @State private var ufes = UFEService()
 
 var body: some View {
 RootView()
 .userFacingErrors(ufes, dismissTitle: "button.ok")
 }
 ```
 
 Anywhere in a view or service, call one of the convenience methods:
 ```swift
 @Environment(UFEService.self) private var ufes
 
 ufes.info(title: "error.title.info1", message: "error.message.info1")
 ufes.warning(title: "error.title.warning1", message: "error.message.warning1")
 ufes.fault(title: "error.title.fault1", message: "error.message.fault1")
 ```
 
 Both keys resolve in the app's `Errors.xcstrings`, at every level. The alert's own button is
 named by the app through `dismissTitle`, usually from its default table. See `StringTable`.
 
 Services that throw their own `UFError` types can hand them in directly:
 ```swift
 ufes.report(MyDomainError.network(underlying: someError))
 ```
 
 Each call is logged through `os.Logger` and replaces any currently presented error. `info` logs at `notice`,
 `warning` at `error` and `fault` at `fault`, so every level survives in the field. The underlying error
 is logged as `Error.logCode`; its description stays private.
 
 */

import OSLog
import SwiftUI

@MainActor
@Observable
public final class UFEService {
    public private(set) var currentError: (any UFError)?
    
    private let logger: Logger
    
    public init(subsystem: String? = nil, category: LogCategory = "UFEService") {
        // Through LoggerService so these errors land in the same subsystem as everything else.
        // A second fallback ladder here would file them elsewhere whenever the bundle has no
        // identifier, and LogExport filters by subsystem — they would vanish from bug reports.
        self.logger = LoggerService(subsystem: subsystem)[category]
    }
    
    public func info(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        error: Error? = nil
    ) {
        report(GenericUFError(title: title, message: message, level: .info, error: error))
    }
    
    public func warning(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        error: Error? = nil
    ) {
        report(GenericUFError(title: title, message: message, level: .warning, error: error))
    }
    
    public func fault(
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        error: Error? = nil
    ) {
        report(GenericUFError(title: title, message: message, level: .fault, error: error))
    }
    
    public func report(_ error: any UFError) {
        log(error)
        currentError = error
    }
    
    public func dismiss() {
        currentError = nil
    }
    
    private func log(_ error: any UFError) {
        let code = error.error?.logCode ?? "none"
        logger.log(
            level: error.level.logType,
            "User-facing error shown: level=\(error.level.name, privacy: .public) \(code, privacy: .public)"
        )
    }
}

private extension UFErrorLevel {
    /// `info` maps to `.default`, which is `notice`: `Logger.info` does not survive in the field.
    var logType: OSLogType {
        switch self {
        case .info: .default
        case .warning: .error
        case .fault: .fault
        }
    }

    var name: String {
        switch self {
        case .info: "info"
        case .warning: "warning"
        case .fault: "fault"
        }
    }
}
