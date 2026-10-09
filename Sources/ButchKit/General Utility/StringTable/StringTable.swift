//
//  StringTable.swift
//  ButchKit
//
//  Created by Leo Heuser on 03.09.26.
//

/**
 
 # StringTable
 Which of the app's catalogs a string is looked up in. ButchKit's own components word themselves
 from their own catalogs; every `LocalizedStringKey` an app hands in resolves in the app's bundle,
 so the app owns that wording and its translations.
 
 Three tables are the convention:
 - `Localizable` — everything by default, buttons included. SwiftUI's own default, so it needs no
   name.
 - `Errors` — anything the user reads because something went wrong. Use `Text(error:)`.
 - `Accessibility` — labels, hints and values only assistive technologies read.
 
 A key rendered without a table lands in `Localizable`, which is the right answer for a button
 even when that button sits in an alert: `button.ok` is a button, not an error.
 
 */

import SwiftUI

public enum StringTable {
    /// The catalog for user-facing error text: `Errors.xcstrings` in the app.
    ///
    /// Named here rather than at each call site so the name is one edit, and so two call sites
    /// cannot quietly disagree about it.
    public static let errors = "Errors"
}

public extension Text {
    /// Renders an error string from the app's `Errors` catalog.
    ///
    /// The bundle stays at its default, which means `Bundle.main` -- the consuming app, exactly
    /// as an untabled `Text` already resolves. Only the table moves.
    ///
    /// - Parameter key: The key, as it is written in `Errors.xcstrings`.
    init(error key: LocalizedStringKey) {
        self.init(key, tableName: StringTable.errors)
    }
}
