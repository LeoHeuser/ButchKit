//
//  ExternalPackagesTexts.swift
//  ButchKit
//
//  Created by Leo Heuser on 14.09.26.
//

import SwiftUI

/// Every word ``ExternalPackagesView`` shows around the packages, handed in by the app.
///
/// ButchKit ships no strings, the same way ``PaywallTexts`` works: each key is written in the
/// app's own code, where Xcode finds it and extracts it into the app's catalog. Declared once and
/// handed to every place that opens the list:
///
/// ```swift
/// let externalPackagesTexts = ExternalPackagesTexts(
///     title: "text.settings.licenses.title",
///     emptyTitle: "text.settings.licenses.empty.title",
///     purpose: Text("text.packages.purpose \(appName)"),
///     sourceHint: String(localized: "accessibility.link.settings.licenses.source", table: "Accessibility"),
///     toggle: { Text("toggle.packages.enabled \($0)") },
///     toggleHint: String(localized: "accessibility.toggle.packages.enabled", table: "Accessibility")
/// )
/// ```
///
/// The same three shapes as there. A label is a `LocalizedStringKey`, a hint is a `String` the app
/// has already resolved from its own table, and a line with a value in it is a `Text` or a
/// closure building one, so the key and its placeholder stand in the app's code together.
public struct ExternalPackagesTexts {
    /// Navigation title of the list.
    public let title: LocalizedStringKey
    /// Title of the empty state, shown when the app hands in no packages.
    public let emptyTitle: LocalizedStringKey
    /// The caption above each package's description, saying it is the app that uses it.
    public let purpose: Text
    /// The VoiceOver hint of a package's row, which opens its source.
    public let sourceHint: String
    /// The switch under an optional package, built from the package's name.
    public let toggle: (String) -> Text
    /// The VoiceOver hint of that switch.
    public let toggleHint: String

    public init(
        title: LocalizedStringKey,
        emptyTitle: LocalizedStringKey,
        purpose: Text,
        sourceHint: String,
        toggle: @escaping (String) -> Text,
        toggleHint: String
    ) {
        self.title = title
        self.emptyTitle = emptyTitle
        self.purpose = purpose
        self.sourceHint = sourceHint
        self.toggle = toggle
        self.toggleHint = toggleHint
    }
}
