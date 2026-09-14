//
//  WebViewSheet.swift
//  ButchKit
//
//  Created by Leo Heuser on 14.09.26.
//

/**
 Presents a web page in a sheet without sending the user out of the app.

 ## Modes
 - `allowsBrowsing: true` (default): Apple's `SFSafariViewController`, with its own Done button,
   reader mode and free navigation. Use it for articles whose links readers should be able to
   follow in place.
 - `allowsBrowsing: false`: the page in a ``GatedWebView`` with a close button. Only the page's
   own domain loads inside the app; links to other domains open in Safari. Use it for legal texts
   and other fixed content, so the app cannot be turned into a general-purpose browser.

 The two modes run on different engines because `SFSafariViewController` offers no way to
 intercept navigation: Apple keeps the browsing inside it private from the host app. A gated
 mode therefore has to be a `WKWebView`. macOS has no `SFSafariViewController` and is always
 gated.

 ## Usage
 ```swift
 .webViewSheet(isPresented: $isShowingArticle, url: articleURL, dismissTitle: "button.done")

 // One sheet for several pages: the item variant builds a fresh sheet per page.
 .webViewSheet(item: $document, url: \.url, dismissTitle: "button.done", title: \.title, allowsBrowsing: false)
 ```
 */

import SwiftUI
#if os(iOS)
import SafariServices
#endif

public extension View {
    /// Presents a web page in a sheet while `isPresented` is `true`.
    ///
    /// - Parameters:
    ///   - isPresented: Whether the sheet is shown.
    ///   - url: The page to show.
    ///   - dismissTitle: The name of the gated sheet's close button, from the app's catalog. The
    ///     Safari mode ignores it, because `SFSafariViewController` brings its own Done button.
    ///   - title: A fixed title for the gated sheet, from the app's catalog. Defaults to `nil`,
    ///     which shows the page's own title. The Safari mode ignores it and shows the domain.
    ///   - allowsBrowsing: Lets the user follow links to any domain inside the app. Defaults to
    ///     `true`; pass `false` to keep the sheet on the page's own domain.
    func webViewSheet(
        isPresented: Binding<Bool>,
        url: URL,
        dismissTitle: LocalizedStringKey,
        title: LocalizedStringKey? = nil,
        allowsBrowsing: Bool = true
    ) -> some View {
        sheet(isPresented: isPresented) {
            WebViewSheetContent(url: url, dismissTitle: dismissTitle, title: title, allowsBrowsing: allowsBrowsing)
        }
    }

    /// Presents the web page of `item` in a sheet while `item` is not `nil`.
    ///
    /// Use this variant when one sheet serves several pages. The page is read once when the sheet
    /// appears, and only a new identity replaces it; with `isPresented`, a page chosen right
    /// before presenting can show the previous one.
    ///
    /// - Parameters:
    ///   - item: The presented item; setting it to `nil` dismisses the sheet.
    ///   - url: The page for the presented item.
    ///   - dismissTitle: The name of the gated sheet's close button, from the app's catalog. The
    ///     Safari mode ignores it, because `SFSafariViewController` brings its own Done button.
    ///   - title: A fixed title per item for the gated sheet, from the app's catalog. Defaults to
    ///     `nil`, which shows the page's own title. The Safari mode ignores it and shows the domain.
    ///   - allowsBrowsing: Lets the user follow links to any domain inside the app. Defaults to
    ///     `true`; pass `false` to keep the sheet on the page's own domain.
    func webViewSheet<Item: Identifiable>(
        item: Binding<Item?>,
        url: @escaping (Item) -> URL,
        dismissTitle: LocalizedStringKey,
        title: ((Item) -> LocalizedStringKey)? = nil,
        allowsBrowsing: Bool = true
    ) -> some View {
        sheet(item: item) { item in
            WebViewSheetContent(url: url(item), dismissTitle: dismissTitle, title: title?(item), allowsBrowsing: allowsBrowsing)
        }
    }
}

private struct WebViewSheetContent: View {
    let url: URL
    let dismissTitle: LocalizedStringKey
    let title: LocalizedStringKey?
    let allowsBrowsing: Bool

    var body: some View {
        #if os(iOS)
        if allowsBrowsing {
            SafariView(url: url)
                .ignoresSafeArea()
        } else {
            GatedSheetContent(url: url, dismissTitle: dismissTitle, title: title)
        }
        #else
        GatedSheetContent(url: url, dismissTitle: dismissTitle, title: title)
        #endif
    }
}

private struct GatedSheetContent: View {
    let url: URL
    let dismissTitle: LocalizedStringKey
    let title: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            GatedWebView(url.absoluteString, navigationTitle: title)
                .sheetDismissButton(dismissTitle)
        }
    }
}

#if os(iOS)
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif

// MARK: - Preview

#Preview("Browsing") {
    @Previewable @State var isPresented = true

    Button("Show Sheet") { isPresented = true }
        .webViewSheet(isPresented: $isPresented, url: URL(string: "https://en.wikipedia.org/wiki/Ivy_Lee")!, dismissTitle: "Close")
}

#Preview("Gated") {
    @Previewable @State var isPresented = true

    Button("Show Sheet") { isPresented = true }
        .webViewSheet(isPresented: $isPresented, url: URL(string: "https://www.apple.com/privacy")!, dismissTitle: "Close", title: "Privacy", allowsBrowsing: false)
}
