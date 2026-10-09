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
///     ExternalPackagesWindow(packages: ExternalPackage.all)
/// }
/// ```
///
/// A window of its own rather than a list pushed inside the `Settings` window, which has no
/// toolbar for a back button. Titled with the list's title, opened at
/// ``ExternalPackagesView/windowSize``, and with a navigation stack of its own, so a package's
/// row can open the package's page.
public struct ExternalPackagesWindow: Scene {
    private let packages: [ExternalPackage]

    public init(packages: [ExternalPackage]) {
        self.packages = packages
    }

    public var body: some Scene {
        Window(Text("label.externalPackages.title", tableName: "ExternalPackages", bundle: .module), id: ExternalPackagesView.windowID) {
            NavigationStack {
                ExternalPackagesView(packages: packages)
            }
        }
        .defaultSize(ExternalPackagesView.windowSize)
    }
}
#endif
