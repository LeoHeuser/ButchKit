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
///     ExternalPackagesLink(packages: ExternalPackage.all, systemImage: "checkmark.seal")
/// }
/// ```
///
/// On iPhone and iPad it pushes the list inside the settings' navigation stack. On the Mac it
/// opens the list's own window, which the app declares once with ``ExternalPackagesWindow``: a
/// `Settings` window has no toolbar for a back button, so a pushed list would have no way back.
///
/// Labeled with the list's title, so the row names the screen it opens.
public struct ExternalPackagesLink: View {
    private let packages: [ExternalPackage]
    private let systemImage: String?

#if os(macOS)
    @Environment(\.openWindow) private var openWindow
#endif

    /// Creates the row.
    ///
    /// - Parameters:
    ///   - packages: The app's packages. Only pushed on iPhone and iPad; the Mac's window gets
    ///     them from ``ExternalPackagesWindow``.
    ///   - systemImage: An SF Symbol in front of the row, for a settings screen whose rows all
    ///     carry one.
    public init(packages: [ExternalPackage], systemImage: String? = nil) {
        self.packages = packages
        self.systemImage = systemImage
    }

    public var body: some View {
#if os(macOS)
        Button {
            openWindow(id: ExternalPackagesView.windowID)
        } label: {
            ExternalPackagesLinkLabel(systemImage: systemImage)
        }
        .accessibilityHint(Text(ExternalPackagesStrings.linkHint))
#else
        NavigationLink {
            ExternalPackagesView(packages: packages)
        } label: {
            ExternalPackagesLinkLabel(systemImage: systemImage)
        }
        .accessibilityHint(Text(ExternalPackagesStrings.linkHint))
#endif
    }
}

/// The row's title, with the symbol in front when the app hands one in.
private struct ExternalPackagesLinkLabel: View {
    let systemImage: String?

    var body: some View {
        if let systemImage {
            Label {
                Text(ExternalPackagesStrings.title)
            } icon: {
                Image(systemName: systemImage)
            }
        } else {
            Text(ExternalPackagesStrings.title)
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        Form {
            ExternalPackagesLink(
                packages: [.previewOptional, .previewRequired],
                systemImage: "checkmark.seal"
            )
        }
    }
}
#endif
