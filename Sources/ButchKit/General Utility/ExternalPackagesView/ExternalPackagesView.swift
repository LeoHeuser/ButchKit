//
//  ExternalPackagesView.swift
//  ButchKit
//
//  Created by Leo Heuser on 02.09.26.
//

import SwiftUI

/// Every external package an app depends on, and the switch for each one the user may turn off.
///
/// ```swift
/// NavigationStack {
///     ExternalPackagesView(packages: ExternalPackage.all, texts: externalPackagesTexts)
/// }
/// ```
///
/// Meant to be opened from wherever it helps: the settings, a privacy screen, an onboarding page.
/// ``ExternalPackagesLink`` is the settings row that opens it. The switches read the same
/// everywhere, because the decision is stored under the package's ``ExternalPackage/ID`` rather
/// than held by the view. A single switch outside the list is an ``ExternalPackageToggle``.
///
/// Inside a navigation stack, because each package's row opens the package's own page with its
/// license, once the app hands in ``ExternalPackagesTexts/Detail`` words.
///
/// One section per package, so an optional package's switch sits with the package it belongs to
/// instead of reading as a list item of its own. The package row stays one link as a whole: a
/// switch inside a link would compete with it for the same tap.
public struct ExternalPackagesView: View {
    /// Names the window this fills on the Mac, where it suits a window of its own better than a
    /// screen pushed inside a `Settings` window, which has no toolbar for a back button. Outside
    /// the `#if` so a settings row, which is one type for both platforms, can name it either way.
    public static let windowID = "external-packages"

#if os(macOS)
    /// How large that window opens.
    ///
    /// A list has no size of its own, so without this the window opens at whatever a single row
    /// asks for. Wide enough for a package name and its license side by side, and tall enough that
    /// a short list does not sit in an empty pane -- the window is resizable from there.
    public static let windowSize = CGSize(width: 480, height: 320)
#endif

    private let packages: [ExternalPackage]
    private let texts: ExternalPackagesTexts

    public init(packages: [ExternalPackage], texts: ExternalPackagesTexts) {
        // Caught in the first preview rather than on a device. The app's tests can ask the same
        // through `ExternalPackage.issues(in:)`.
        assert(
            ExternalPackage.issues(in: packages).isEmpty,
            ExternalPackage.issues(in: packages).joined(separator: "\n")
        )
        self.packages = packages
        self.texts = texts
    }

    public var body: some View {
        List(packages) { package in
            Section {
                ExternalPackageRow(package: package, texts: texts)

                if package.isOptional {
                    ExternalPackageToggle(package: package, texts: texts)
                }
            } footer: {
                // What the switch does not say itself, such as when it takes full effect.
                if package.isOptional, let note = package.note {
                    Text(note)
                }
            }
        }
        // Laid over the list rather than replacing it: the list is what tracks the navigation bar.
        .overlay {
            if packages.isEmpty {
                ContentUnavailableView(texts.emptyTitle, systemImage: "shippingbox")
            }
        }
        .navigationTitle(texts.title)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ExternalPackagesView(packages: [.previewOptional, .previewRequired], texts: .preview)
    }
}

#Preview("Empty") {
    NavigationStack {
        ExternalPackagesView(packages: [], texts: .preview)
    }
}
#endif
