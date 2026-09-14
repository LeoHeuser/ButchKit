//
//  GatedWebView.swift
//  ButchKit
//
//  Created by Leo Heuser on 29.01.26.
//

/**
 A web view for fixed, trusted content that decides which tapped links stay in it.

 ## Features
 - Loads a single URL; ``WebBrowsing`` decides how far the user may follow links from there
 - Automatically sends Accept-Language headers based on device or app language
 - Configurable JavaScript support (disabled by default for security)
 - Configurable cache policy (bypasses cache by default for always-fresh content)
 - Links it does not keep open in Safari automatically
 - Automatic URL validation with error handling
 - Designed to be used within a NavigationStack for title display
 - Supports custom navigation title or automatic website title
 
 ## Usage
 ```swift
 // Basic usage - title from website
 GatedWebView("https://example.com/privacy")
 
 // Custom navigation title
 GatedWebView("apple.com/privacy", navigationTitle: "Privacy Policy")
 
 // URLs without scheme automatically get https:// prefix
 GatedWebView("apple.com/privacy")  // → https://apple.com/privacy
 GatedWebView("www.apple.com")      // → https://www.apple.com
 
 // With custom options
 GatedWebView(
 "example.com",
 navigationTitle: "Terms",
 useAppLanguage: true,
 allowsJavaScript: true,
 cachePolicy: .useProtocolCachePolicy
 )
 ```
 
 ## URL Validation
 - URLs must contain at least one dot (e.g., "apple.com")
 - URLs without http/https scheme automatically get "https://" prefix
 - Invalid URLs (e.g., "lol") show an error indicator
 
 ## Security
 - JavaScript is disabled by default
 - Tapped links follow `allowsBrowsing`: `.onSameDomain` by default, `.none` for pages that are
   only there to be read
 - Tapped links the view does not keep open in Safari
 - The first page and its redirects always load
 */

import SwiftUI
import WebKit

public struct GatedWebView: View {
    let url: String
    let useAppLanguage: Bool
    let allowsJavaScript: Bool
    let cachePolicy: URLRequest.CachePolicy
    let navigationTitle: LocalizedStringKey?
    let allowsBrowsing: WebBrowsing

    @State private var pageTitle: String = ""

    /// - Parameter allowsBrowsing: Which tapped links stay in the view. Defaults to
    ///   `.onSameDomain`.
    public init(
        _ url: String,
        navigationTitle: LocalizedStringKey? = nil,
        useAppLanguage: Bool = false,
        allowsJavaScript: Bool = false,
        cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData,
        allowsBrowsing: WebBrowsing = .onSameDomain
    ) {
        self.url = url
        self.navigationTitle = navigationTitle
        self.useAppLanguage = useAppLanguage
        self.allowsJavaScript = allowsJavaScript
        self.cachePolicy = cachePolicy
        self.allowsBrowsing = allowsBrowsing
    }
    
    public var body: some View {
        if let validUrl = normalizedURL(from: url) {
            GatedWebViewRepresentable(
                url: validUrl,
                useAppLanguage: useAppLanguage,
                allowsJavaScript: allowsJavaScript,
                cachePolicy: cachePolicy,
                allowsBrowsing: allowsBrowsing,
                pageTitle: $pageTitle
            )
            .navigationTitle(navigationTitle.map { Text($0) } ?? Text(pageTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        } else {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    private func normalizedURL(from urlString: String) -> URL? {
        guard urlString.contains(".") else { return nil }
        if let url = URL(string: urlString), url.scheme == "http" || url.scheme == "https" {
            return url
        }
        return URL(string: "https://" + urlString)
    }
}

// MARK: - Web View Representable

#if os(iOS)
@MainActor
private struct GatedWebViewRepresentable: UIViewRepresentable {
    let url: URL
    let useAppLanguage: Bool
    let allowsJavaScript: Bool
    let cachePolicy: URLRequest.CachePolicy
    let allowsBrowsing: WebBrowsing
    @Binding var pageTitle: String
    @Environment(\.openURL) private var openURL

    func makeUIView(context: Context) -> WKWebView {
        configuredWebView(coordinator: context.coordinator)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> NavigationHandler {
        NavigationHandler(startURL: url, allowsBrowsing: allowsBrowsing, openURL: openURL, pageTitle: $pageTitle)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: NavigationHandler) {
        webView.removeObserver(coordinator, forKeyPath: "title")
    }
}
#elseif os(macOS)
@MainActor
private struct GatedWebViewRepresentable: NSViewRepresentable {
    let url: URL
    let useAppLanguage: Bool
    let allowsJavaScript: Bool
    let cachePolicy: URLRequest.CachePolicy
    let allowsBrowsing: WebBrowsing
    @Binding var pageTitle: String
    @Environment(\.openURL) private var openURL

    func makeNSView(context: Context) -> WKWebView {
        configuredWebView(coordinator: context.coordinator)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> NavigationHandler {
        NavigationHandler(startURL: url, allowsBrowsing: allowsBrowsing, openURL: openURL, pageTitle: $pageTitle)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: NavigationHandler) {
        webView.removeObserver(coordinator, forKeyPath: "title")
    }
}
#endif

private extension GatedWebViewRepresentable {
    func configuredWebView(coordinator: NavigationHandler) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = allowsJavaScript

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = coordinator

        var request = URLRequest(url: url, cachePolicy: cachePolicy)
        let languages = useAppLanguage ? Bundle.main.preferredLocalizations : Locale.preferredLanguages
        request.setValue(languages.joined(separator: ", "), forHTTPHeaderField: "Accept-Language")

        webView.addObserver(coordinator, forKeyPath: "title", options: .new, context: nil)
        webView.load(request)

        return webView
    }
}

// MARK: - Navigation Handler

@MainActor
final class NavigationHandler: NSObject, WKNavigationDelegate {
    private let startURL: URL
    private let allowsBrowsing: WebBrowsing
    private let openURL: OpenURLAction
    @Binding private var pageTitle: String

    init(startURL: URL, allowsBrowsing: WebBrowsing, openURL: OpenURLAction, pageTitle: Binding<String>) {
        self.startURL = startURL
        self.allowsBrowsing = allowsBrowsing
        self.openURL = openURL
        self._pageTitle = pageTitle
        super.init()
    }
    
    override nonisolated func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "title", let webView = object as? WKWebView {
            Task { @MainActor in pageTitle = webView.title ?? "" }
        }
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let requestUrl = navigationAction.request.url else { return .cancel }
        guard webView.url != nil else { return .allow }

        if navigationAction.navigationType == .linkActivated,
           !allowsBrowsing.keepsInApp(requestUrl, startURL: startURL, currentURL: webView.url) {
            openURL(requestUrl)
            return .cancel
        }
        
        return .allow
    }
}

// MARK: - Preview

#Preview("Default (Website Title)") {
    NavigationStack {
        GatedWebView("https://www.apple.com/privacy")
    }
}

#Preview("Custom Title") {
    NavigationStack {
        GatedWebView("apple.com/privacy", navigationTitle: "Privacy Policy")
    }
}

#Preview("Invalid URL") {
    GatedWebView("wrong")
}

#Preview("With All Options") {
    NavigationStack {
        GatedWebView(
            "example.com",
            navigationTitle: "Terms & Conditions",
            useAppLanguage: true,
            allowsJavaScript: true,
            cachePolicy: .useProtocolCachePolicy,
            allowsBrowsing: .none
        )
    }
}
