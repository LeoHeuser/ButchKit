//
//  WebViewButton.swift
//  Butch
//
//  Created by Leo Heuser on 26.05.25.
//

/**
 A button that presents web content in a sheet using GatedWebView.

 ## Features
 - Displays web content in a modal sheet
 - Automatically handles language detection via Accept-Language headers
 - Auto-adds https:// prefix to URLs without scheme
 - Optional icon support with SF Symbols
 - Configurable JavaScript, language, and cache settings

 ## Usage
 ```swift
 // Simple usage (auto-adds https://)
 WebViewButton("button.privacy", url: "apple.com/privacy", dismissTitle: "button.dismissSheet")

 // With icon
 WebViewButton("button.support", systemImage: "questionmark.circle", url: "example.com/support", dismissTitle: "button.dismissSheet")

 // With custom settings
 WebViewButton(
 "button.help",
 url: "example.com/help",
 dismissTitle: "button.dismissSheet",
 useAppLanguage: true,
 allowsJavaScript: true
 )
 ```
 */

import SwiftUI

public struct WebViewButton: View {
    // MARK: - Properties
    let title: LocalizedStringKey
    let systemImage: String?
    let url: String
    let dismissTitle: LocalizedStringKey
    let useAppLanguage: Bool
    let allowsJavaScript: Bool
    let cachePolicy: URLRequest.CachePolicy

    @State private var showingWebView = false

    // MARK: - Initializer
    /// - Parameter dismissTitle: The name of the sheet's close button, from the app's catalog.
    public init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        url: String,
        dismissTitle: LocalizedStringKey,
        useAppLanguage: Bool = false,
        allowsJavaScript: Bool = false,
        cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    ) {
        self.title = title
        self.systemImage = systemImage
        self.url = url
        self.dismissTitle = dismissTitle
        self.useAppLanguage = useAppLanguage
        self.allowsJavaScript = allowsJavaScript
        self.cachePolicy = cachePolicy
    }

    // MARK: - View
    public var body: some View {
        Button {
            showingWebView = true
        } label: {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .sheet(isPresented: $showingWebView) {
            NavigationStack {
                GatedWebView(
                    url,
                    navigationTitle: title,
                    useAppLanguage: useAppLanguage,
                    allowsJavaScript: allowsJavaScript,
                    cachePolicy: cachePolicy
                )
                .sheetDismissButton(dismissTitle)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Form {
        WebViewButton(
            "Imprint",
            url: "apple.com",
            dismissTitle: "Close"
        )

        WebViewButton(
            "Privacy",
            systemImage: "lock.shield",
            url: "apple.com/privacy",
            dismissTitle: "Close"
        )

        WebViewButton(
            "Support (with JS)",
            systemImage: "questionmark.circle",
            url: "apple.com/support",
            dismissTitle: "Close",
            allowsJavaScript: true
        )
    }
}
