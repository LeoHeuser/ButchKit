//
//  ExternalPackagesStrings.swift
//  ButchKit
//
//  Created by Leo Heuser on 09.10.26.
//

import Foundation

/// Every word ``ExternalPackagesView`` shows around the packages, from `ExternalPackages.xcstrings`
/// in this module. The packages' own descriptions and notes stay the app's, see ``ExternalPackage``.
///
/// Resources rather than strings, so SwiftUI resolves each one when it draws, in the language the
/// app runs in. The English stands here as the default value, which Xcode extracts into the
/// catalog as its source.
enum ExternalPackagesStrings {
    static var title: LocalizedStringResource {
        LocalizedStringResource("label.externalPackages.title", defaultValue: "Licenses", table: "ExternalPackages", bundle: .module,
                                comment: "Title of the list of third-party software the app uses, with their licenses. Also the settings row that opens it.")
    }

    static var linkHint: LocalizedStringResource {
        LocalizedStringResource("accessibility.hint.externalPackages.link", defaultValue: "Shows the licenses of third-party software.", table: "ExternalPackages", bundle: .module,
                                comment: "VoiceOver hint of the settings row that opens the licenses list.")
    }

    static var emptyTitle: LocalizedStringResource {
        LocalizedStringResource("label.externalPackages.empty", defaultValue: "No Licenses", table: "ExternalPackages", bundle: .module,
                                comment: "Empty-state title of the licenses list.")
    }

    static var purpose: LocalizedStringResource {
        LocalizedStringResource("label.externalPackages.purpose", defaultValue: "Purpose in \(appName)", table: "ExternalPackages", bundle: .module,
                                comment: "Caption above what a package is used for, in the licenses list. The placeholder is the app's name.")
    }

    static var openHint: LocalizedStringResource {
        LocalizedStringResource("accessibility.hint.externalPackages.open", defaultValue: "Shows the license of this package.", table: "ExternalPackages", bundle: .module,
                                comment: "VoiceOver hint of a package's row in the licenses list, which opens its license page.")
    }

    static var source: LocalizedStringResource {
        LocalizedStringResource("button.externalPackages.source", defaultValue: "Source Code", table: "ExternalPackages", bundle: .module,
                                comment: "Link on a package's license page that opens its source code in the browser.")
    }

    static var sourceHint: LocalizedStringResource {
        LocalizedStringResource("accessibility.hint.externalPackages.source", defaultValue: "Opens the source code in the browser.", table: "ExternalPackages", bundle: .module,
                                comment: "VoiceOver hint of that link, which leaves the app.")
    }

    static func toggle(_ packageName: String) -> LocalizedStringResource {
        LocalizedStringResource("label.externalPackages.toggle", defaultValue: "Use \(packageName)", table: "ExternalPackages", bundle: .module,
                                comment: "Switch that turns an optional package on or off. The placeholder is the package's name, for example an analytics service.")
    }

    static var toggleHint: LocalizedStringResource {
        LocalizedStringResource("accessibility.hint.externalPackages.toggle", defaultValue: "Decides whether \(appName) uses this package.", table: "ExternalPackages", bundle: .module,
                                comment: "VoiceOver hint of that switch. The placeholder is the app's name.")
    }

    /// The app's name as the Home Screen shows it, in the app's language, read from the bundle so a
    /// renamed app does not leave the old name in the list.
    private static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? ""
    }
}

private extension LocalizedStringResource.BundleDescription {
    /// This module's resource bundle, where `ExternalPackages.xcstrings` is compiled to.
    static var module: Self { .atURL(Bundle.module.bundleURL) }
}
