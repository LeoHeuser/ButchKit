//
//  StaticWebView.swift
//  ButchKit
//
//  Created by Leo Heuser on 29.01.26.
//

/**
 A static, security-focused web view component for displaying web content.
 
 ## Features
 - Loads a single URL without allowing navigation away from the initial domain
 - Automatically sends Accept-Language headers based on device or app language
 - Configurable JavaScript support (disabled by default for security)
 - Configurable cache policy (bypasses cache by default for always-fresh content)
 - External links open in Safari automatically
 - Automatic URL validation with error handling
 - Designed to be used within a NavigationStack for title display
 - Supports custom navigation title or automatic website title
 
 ## Usage
 ```swift
 // Basic usage - title from website
 StaticWebView("https://example.com/privacy")
 
 // Custom navigation title
 StaticWebView("apple.com/privacy", navigationTitle: "Privacy Policy")
 
 // URLs without scheme automatically get https:// prefix
 StaticWebView("apple.com/privacy")  // → https://apple.com/privacy
 StaticWebView("www.apple.com")      // → https://www.apple.com
 
 // With custom options
 StaticWebView(
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
 - Navigation is restricted to the same domain
 - User-activated links to external domains open in Safari
 - Redirects and server-side navigation within the same domain are allowed
 */

import SwiftUI
import WebKit

public struct StaticWebView: View {
    let url: String
    let useAppLanguage: Bool
    let allowsJavaScript: Bool
    let cachePolicy: URLRequest.CachePolicy
    let navigationTitle: LocalizedStringKey?
    
    @State private var pageTitle: String = ""
    
    public init(
        _ url: String,
        navigationTitle: LocalizedStringKey? = nil,
        useAppLanguage: Bool = false,
        allowsJavaScript: Bool = false,
        cachePolicy: URLRequest.CachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    ) {
        self.url = url
        self.navigationTitle = navigationTitle
        self.useAppLanguage = useAppLanguage
        self.allowsJavaScript = allowsJavaScript
        self.cachePolicy = cachePolicy
    }
    
    public var body: some View {
        if let validUrl = normalizedURL(from: url) {
            StaticWebViewRepresentable(
                url: validUrl,
                useAppLanguage: useAppLanguage,
                allowsJavaScript: allowsJavaScript,
                cachePolicy: cachePolicy,
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
private struct StaticWebViewRepresentable: UIViewRepresentable {
    let url: URL
    let useAppLanguage: Bool
    let allowsJavaScript: Bool
    let cachePolicy: URLRequest.CachePolicy
    @Binding var pageTitle: String
    @Environment(\.openURL) private var openURL

    func makeUIView(context: Context) -> WKWebView {
        configuredWebView(coordinator: context.coordinator)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> NavigationHandler {
        NavigationHandler(allowedUrl: url, openURL: openURL, pageTitle: $pageTitle)
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: NavigationHandler) {
        webView.removeObserver(coordinator, forKeyPath: "title")
    }
}
#elseif os(macOS)
@MainActor
private struct StaticWebViewRepresentable: NSViewRepresentable {
    let url: URL
    let useAppLanguage: Bool
    let allowsJavaScript: Bool
    let cachePolicy: URLRequest.CachePolicy
    @Binding var pageTitle: String
    @Environment(\.openURL) private var openURL

    func makeNSView(context: Context) -> WKWebView {
        configuredWebView(coordinator: context.coordinator)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> NavigationHandler {
        NavigationHandler(allowedUrl: url, openURL: openURL, pageTitle: $pageTitle)
    }

    static func dismantleNSView(_ webView: WKWebView, coordinator: NavigationHandler) {
        webView.removeObserver(coordinator, forKeyPath: "title")
    }
}
#endif

private extension StaticWebViewRepresentable {
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
    private let allowedUrl: URL
    private let openURL: OpenURLAction
    @Binding private var pageTitle: String
    
    init(allowedUrl: URL, openURL: OpenURLAction, pageTitle: Binding<String>) {
        self.allowedUrl = allowedUrl
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
    
    private func isSameDomain(_ url1: URL, _ url2: URL) -> Bool {
        func normalizedHost(_ url: URL) -> String {
            url.host?.lowercased().replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression) ?? ""
        }
        let host1 = normalizedHost(url1)
        return !host1.isEmpty && host1 == normalizedHost(url2)
    }
    
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        guard let requestUrl = navigationAction.request.url else { return .cancel }
        guard webView.url != nil else { return .allow }
        
        if navigationAction.navigationType == .linkActivated, !isSameDomain(requestUrl, allowedUrl) {
            openURL(requestUrl)
            return .cancel
        }
        
        return .allow
    }
}

// MARK: - Preview

#Preview("Default (Website Title)") {
    NavigationStack {
        StaticWebView("https://www.apple.com/privacy")
    }
}

#Preview("Custom Title") {
    NavigationStack {
        StaticWebView("apple.com/privacy", navigationTitle: "Privacy Policy")
    }
}

#Preview("Invalid URL") {
    StaticWebView("wrong")
}

#Preview("With All Options") {
    NavigationStack {
        StaticWebView(
            "example.com",
            navigationTitle: "Terms & Conditions",
            useAppLanguage: true,
            allowsJavaScript: true,
            cachePolicy: .useProtocolCachePolicy
        )
    }
}
