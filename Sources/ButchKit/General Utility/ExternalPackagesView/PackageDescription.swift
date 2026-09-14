//
//  PackageDescription.swift
//  ButchKit
//
//  Created by Leo Heuser on 02.09.26.
//

import Foundation

/// One external package: its name, license, what it does, where its source lives, and whether
/// the user may turn it off. ``ExternalPackagesView`` renders one section per entry, so
/// acknowledging a new package is only ever adding one to the app's list.
///
/// `name` and `license` are not language, so they stay plain strings. `description` is, and the
/// initializer resolves it through `String(localized:)` itself. Without a bundle that lookup
/// runs in `Bundle.main`, the consuming app, so the key is written at the app's call site and
/// lands in the app's catalog like any other string -- ButchKit still names no keys.
public struct PackageDescription: Identifiable, Sendable {
    public let id: PackageID
    public let name: String
    public let license: String
    public let description: String
    public let url: URL

    /// Whether the user may turn the package off, which puts a switch under it.
    public let isOptional: Bool

    /// What the app does the moment the user flips that switch: start the package when it turns
    /// on, clean up after it when it turns off.
    ///
    /// ```swift
    /// onEnabledChange: { isEnabled in
    ///     if isEnabled {
    ///         Analytics.start()
    ///     } else {
    ///         Analytics.stop()
    ///         Analytics.deleteCache()
    ///     }
    /// }
    /// ```
    ///
    /// What it promises:
    /// - It runs on the main actor, so it can call anything the app's own code can.
    /// - It runs once per flip by the user, and only when the value really changed.
    /// - The new value is already stored when it runs, so ``PackageID/isEnabled`` agrees with it.
    /// - It does not run at launch. Whatever starts the package then reads ``PackageID/isEnabled``.
    ///
    /// Declared on the package rather than handed to the view, so every place that opens the list
    /// gets the same reaction and none of them can forget to wire it. The list is usually a static
    /// constant, so this reaches static API, such as an SDK's own entry points, rather than an
    /// instance the app holds in its state.
    public let onEnabledChange: (@MainActor @Sendable (Bool) -> Void)?

    /// `url` takes the address as a plain string, unwrapped here rather than at every entry: each
    /// one is a literal written by the app, not something that can fail short of a typo, and a
    /// typo is caught the moment the entry is previewed or shown.
    public init(
        id: PackageID,
        name: String,
        license: String,
        description: String.LocalizationValue,
        url: String,
        isOptional: Bool = false,
        onEnabledChange: (@MainActor @Sendable (Bool) -> Void)? = nil
    ) {
        self.id = id
        self.name = name
        self.license = license
        self.description = String(localized: description)
        self.url = URL(string: url)!
        self.isOptional = isOptional
        self.onEnabledChange = onEnabledChange
    }
}
