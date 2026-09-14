//
//  WebBrowsing.swift
//  ButchKit
//
//  Created by Leo Heuser on 14.09.26.
//

import Foundation

/// How far a web view lets the user follow links before handing them to the default browser.
///
/// Only links the user taps are judged: the first page and its redirects always load. A jump to
/// an anchor on the page being shown stays in place in every case, so a table of contents keeps
/// working even under ``none``.
///
/// Parameters of this type are never optional, so ``none`` cannot be mistaken for
/// `Optional.none`.
public enum WebBrowsing: Sendable {
    /// Every tapped link opens in the default browser, even one on the same website. For pages
    /// that are only there to be read, such as legal texts.
    case none
    /// Links to the starting page's domain and its subdomains stay in the app; any other domain
    /// opens in the default browser. A leading `www.` does not count, so a page starting on
    /// `www.apple.com` keeps `apple.com` and `support.apple.com`, but not `google.com`.
    case onSameDomain
    /// Every link stays in the app.
    case everywhere

    /// Whether a tapped link to `url` loads in the app rather than in the default browser.
    ///
    /// - Parameters:
    ///   - url: Where the link leads.
    ///   - startURL: The page the web view was opened with, which sets the domain.
    ///   - currentURL: The page shown when the link was tapped, for anchor jumps on it.
    func keepsInApp(_ url: URL, startURL: URL, currentURL: URL?) -> Bool {
        if let currentURL, url.isAnchor(on: currentURL) { return true }

        switch self {
        case .none:
            return false
        case .onSameDomain:
            return url.isOnDomain(of: startURL)
        case .everywhere:
            return true
        }
    }
}

private extension URL {
    /// A link to a spot on `page` itself. Without an anchor the same address is a reload, which
    /// counts as navigation.
    func isAnchor(on page: URL) -> Bool {
        guard fragment != nil, let target = withoutFragment else { return false }
        return target == page.withoutFragment
    }

    /// The same host as `start` or one of its subdomains. The dot in the suffix keeps a
    /// look-alike such as `evilapple.com` from passing as `apple.com`.
    func isOnDomain(of start: URL) -> Bool {
        guard let host = siteHost, let base = start.siteHost, !base.isEmpty else { return false }
        return host == base || host.hasSuffix("." + base)
    }

    var withoutFragment: URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        return components?.url
    }

    /// The host in lowercase without a leading `www.`, which names the same site.
    var siteHost: String? {
        guard let host = host()?.lowercased() else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}
