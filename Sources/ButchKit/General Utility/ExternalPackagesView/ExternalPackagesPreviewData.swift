//
//  ExternalPackagesPreviewData.swift
//  ButchKit
//
//  Created by Leo Heuser on 14.09.26.
//

#if DEBUG
import SwiftUI

// Every preview of the external packages list draws from these, so the sample copy lives in one place.

extension ExternalPackagesTexts {
    /// Plain words, since a ButchKit preview has no app catalog to look a key up in. Computed,
    /// because the struct is not `Sendable`, which a static constant would require.
    static var preview: ExternalPackagesTexts {
        ExternalPackagesTexts(
            title: "External packages",
            emptyTitle: "No packages",
            purpose: Text(verbatim: "What this app uses it for"),
            sourceHint: "Opens the source of this package.",
            toggle: { Text(verbatim: "Use \($0)") },
            toggleHint: "Lets the app use this package."
        )
    }
}

extension ExternalPackage {
    /// A package the user may turn off, so its section carries the switch.
    static let previewOptional = ExternalPackage(
        id: ID("previewOptional"),
        name: "Optional Package",
        license: "MIT",
        description: "An example description of what this package does.",
        url: "https://www.apple.com",
        isOptional: true
    )

    /// A package the app cannot run without, so its section is the row alone.
    static let previewRequired = ExternalPackage(
        id: ID("previewRequired"),
        name: "Required Package",
        license: "Apache 2.0",
        description: "A package the app cannot run without.",
        url: "https://www.apple.com"
    )

    /// A name and a description long enough to wrap, for the row's layout.
    static let previewLong = ExternalPackage(
        id: ID("previewLong"),
        name: "Long Example Package Lorem ipsum dolor sit amet consectetuer adipiscing elit ligula eget dolor",
        license: "MIT",
        description: "Donec vitae sapien ut libero venenatis faucibus. Nullam quis ante. Etiam sit amet orci eget eros faucibus tincidunt. Duis leo. Sed fringilla mauris sit amet nibh. Donec sodales sagittis magna.",
        url: "https://www.apple.com"
    )
}
#endif
