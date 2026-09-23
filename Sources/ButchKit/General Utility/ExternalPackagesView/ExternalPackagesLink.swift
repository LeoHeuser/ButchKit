//
//  ExternalPackagesLink.swift
//  ButchKit
//
//  Created by Leo Heuser on 23.09.26.
//

import SwiftUI

/// The settings row that opens ``ExternalPackagesView``, the way each platform expects.
///
/// ```swift
/// Section {
///     ExternalPackagesLink(packages: ExternalPackage.all, texts: externalPackagesTexts, systemImage: "checkmark.seal")
/// }
/// ```
///
/// On iPhone and iPad it pushes the list inside the settings' navigation stack. On the Mac it
/// opens the list's own window, which the app declares once with ``ExternalPackagesWindow``: a
/// `Settings` window has no toolbar for a back button, so a pushed list would have no way back.
///
/// Labeled with the list's ``ExternalPackagesTexts/title``, so the row names the screen it opens.
public struct ExternalPackagesLink: View {
    private let packages: [ExternalPackage]
    private let texts: ExternalPackagesTexts
    private let systemImage: String?
    private let hint: String?

#if os(macOS)
    @Environment(\.openWindow) private var openWindow
#endif

    /// Creates the row.
    ///
    /// - Parameters:
    ///   - packages: The app's packages. Only pushed on iPhone and iPad; the Mac's window gets
    ///     them from ``ExternalPackagesWindow``.
    ///   - texts: The app's words for the list.
    ///   - systemImage: An SF Symbol in front of the row, for a settings screen whose rows all
    ///     carry one.
    ///   - hint: The row's VoiceOver hint, resolved by the app from its own table.
    public init(
        packages: [ExternalPackage],
        texts: ExternalPackagesTexts,
        systemImage: String? = nil,
        hint: String? = nil
    ) {
        self.packages = packages
        self.texts = texts
        self.systemImage = systemImage
        self.hint = hint
    }

    public var body: some View {
#if os(macOS)
        Button {
            openWindow(id: ExternalPackagesView.windowID)
        } label: {
            ExternalPackagesLinkLabel(title: texts.title, systemImage: systemImage)
        }
        .accessibilityHint(hint ?? "")
#else
        NavigationLink {
            ExternalPackagesView(packages: packages, texts: texts)
        } label: {
            ExternalPackagesLinkLabel(title: texts.title, systemImage: systemImage)
        }
        .accessibilityHint(hint ?? "")
#endif
    }
}

/// The row's title, with the symbol in front when the app hands one in.
private struct ExternalPackagesLinkLabel: View {
    let title: LocalizedStringKey
    let systemImage: String?

    var body: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
        } else {
            Text(title)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        Form {
            ExternalPackagesLink(
                packages: [.previewOptional, .previewRequired],
                texts: .preview,
                systemImage: "checkmark.seal"
            )
        }
    }
}
#endif
