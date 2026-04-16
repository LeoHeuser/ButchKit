//
//  WebViewButton.swift
//  Butch
//
//  Created by Leo Heuser on 26.05.25.
//

/**
 A button that presents web content in a sheet using StaticWebView.
 
 ## Features
 - Displays web content in a modal sheet
 - Automatically handles language detection via Accept-Language headers
 - Auto-adds https:// prefix to URLs without scheme
 - Optional icon support with SF Symbols
 - Configurable JavaScript, language, and cache settings
 
 ## Usage
 ```swift
 // Simple usage (auto-adds https://)
 WebViewButton("Privacy", url: "apple.com/privacy")
 
 // With icon
 WebViewButton("Support", systemImage: "questionmark.circle", url: "example.com/support")
 
 // With custom settings
 WebViewButton(
 "Help",
 url: "example.com/help",
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
    let useAppLanguage: Bool
    let allowsJavaScript: Bool
    let cachePolicy: URLRequest.CachePolicy
    
    @State private var showingWebView = false
    
    // MARK: - Initializer
    public init(
        _ title: LocalizedStringKey,
        systemImage: String? = nil,
        url: String,
        useAppLanguage: Bool = false,
        allowsJavaScript: Bool = false,
        cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    ) {
        self.title = title
        self.systemImage = systemImage
        self.url = url
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
                StaticWebView(
                    url,
                    navigationTitle: title,
                    useAppLanguage: useAppLanguage,
                    allowsJavaScript: allowsJavaScript,
                    cachePolicy: cachePolicy
                )
                .sheetDismissButton()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    Form {
        WebViewButton(
            "Imprint",
            url: "apple.com"
        )
        
        WebViewButton(
            "Privacy",
            systemImage: "lock.shield",
            url: "apple.com/privacy"
        )
        
        WebViewButton(
            "Support (with JS)",
            systemImage: "questionmark.circle",
            url: "apple.com/support",
            allowsJavaScript: true
        )
    }
}
