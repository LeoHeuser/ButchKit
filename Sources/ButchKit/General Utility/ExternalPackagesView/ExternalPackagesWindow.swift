//
//  ExternalPackagesWindow.swift
//  ButchKit
//
//  Created by Leo Heuser on 23.09.26.
//

#if os(macOS)
import SwiftUI

/// The Mac's window for ``ExternalPackagesView``, which ``ExternalPackagesLink`` opens.
///
/// Declared once, next to the app's other scenes:
///
/// ```swift
/// var body: some Scene {
///     WindowGroup { ContentView() }
///
///     ExternalPackagesWindow(packages: ExternalPackage.all, texts: externalPackagesTexts)
/// }
/// ```
///
/// A window of its own rather than a list pushed inside the `Settings` window, which has no
/// toolbar for a back button. Titled with the list's ``ExternalPackagesTexts/title``, opened at
/// ``ExternalPackagesView/windowSize``, and with a navigation stack of its own, so a package's
/// row can open the package's page.
public struct ExternalPackagesWindow: Scene {
    private let packages: [ExternalPackage]
    private let texts: ExternalPackagesTexts

    public init(packages: [ExternalPackage], texts: ExternalPackagesTexts) {
        self.packages = packages
        self.texts = texts
    }

    public var body: some Scene {
        Window(texts.title, id: ExternalPackagesView.windowID) {
            NavigationStack {
                ExternalPackagesView(packages: packages, texts: texts)
            }
        }
        .defaultSize(ExternalPackagesView.windowSize)
    }
}
#endif
