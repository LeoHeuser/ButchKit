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
        previewTexts(detail: .preview)
    }

    /// The same words without a package page, so each row opens its source directly.
    static var previewWithoutDetail: ExternalPackagesTexts {
        previewTexts(detail: nil)
    }

    private static func previewTexts(detail: Detail?) -> ExternalPackagesTexts {
        ExternalPackagesTexts(
            title: "External packages",
            emptyTitle: "No packages",
            purpose: Text(verbatim: "What this app uses it for"),
            sourceHint: "Opens the source of this package.",
            toggle: { Text(verbatim: "Use \($0)") },
            toggleHint: "Lets the app use this package.",
            detail: detail
        )
    }
}

extension ExternalPackagesTexts.Detail {
    static let preview = ExternalPackagesTexts.Detail(
        source: "Source code",
        openHint: "Shows the license of this package."
    )
}

extension ExternalPackage.ID {
    static let previewOptional = ExternalPackage.ID("previewOptional", availability: .optOut)
    static let previewRequired = ExternalPackage.ID("previewRequired", availability: .required)
    static let previewLong = ExternalPackage.ID("previewLong", availability: .required)
}

extension ExternalPackage {
    /// A package the user may turn off, so its section carries the switch and a note under it.
    static let previewOptional = ExternalPackage(
        id: .previewOptional,
        name: "Optional Package",
        license: .mit(copyright: "Copyright (c) 2024 Example Author"),
        description: "An example description of what this package does.",
        url: "https://example.com",
        note: "Turning it off takes full effect at the next launch."
    )

    /// A package the app cannot run without, so its section is the row alone.
    static let previewRequired = ExternalPackage(
        id: .previewRequired,
        name: "Required Package",
        license: .apache2(copyright: "Copyright 2024 Example Organization"),
        description: "A package the app cannot run without.",
        url: "https://example.com"
    )

    /// A name and a description long enough to wrap, for the row's layout, under a license known
    /// by name alone.
    static let previewLong = ExternalPackage(
        id: .previewLong,
        name: "Long Example Package Lorem ipsum dolor sit amet consectetuer adipiscing elit ligula eget dolor",
        license: .custom(name: "Proprietary"),
        description: "Donec vitae sapien ut libero venenatis faucibus. Nullam quis ante. Etiam sit amet orci eget eros faucibus tincidunt. Duis leo. Sed fringilla mauris sit amet nibh. Donec sodales sagittis magna.",
        url: "https://example.com"
    )
}
#endif
