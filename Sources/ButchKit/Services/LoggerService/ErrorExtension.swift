//
//  ErrorExtension.swift
//  ButchKit
//
//  Created by Leo Heuser on 04.09.26.
//

import Foundation

public extension Error {
    /// `domain=… code=…`, the two fields that make an error actionable in a report.
    ///
    /// `localizedDescription` is prose. Foundation fills it with whatever it has, a file name
    /// included, so it is neither greppable nor safe to log. Domain
    /// and code are constants of the framework that threw, and the pair names the failure
    /// exactly. A Swift error type that is not an `NSError` bridges to its type name as the
    /// domain and its case index as the code, which still identifies it.
    ///
    /// ```swift
    /// Logger.store.error("Save failed: \(error.logCode, privacy: .public)")
    /// ```
    var logCode: String {
        let failure = self as NSError
        return "domain=\(failure.domain) code=\(failure.code)"
    }
}
