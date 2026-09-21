//
//  WebViewSheet.swift
//  ButchKit
//
//  Created by Leo Heuser on 14.09.26.
//

/**
 Presents a web page in a sheet without sending the user out of the app.

 ## Modes
 `allowsBrowsing` takes a ``WebBrowsing``:
 - `.everywhere` (default): Apple's `SFSafariViewController`, with its own Done button, reader
   mode and free navigation. Use it for articles whose links readers should be able to follow in
   place.
 - `.onSameDomain`: the page in a ``GatedWebView`` with a close button. Links to the page's
   domain and its subdomains stay inside the app; links to other domains open in Safari.
 - `.none`: the same gated sheet, but every tapped link opens in Safari. Use it for legal texts
   and other pages that are only there to be read, so the app cannot be turned into a
   general-purpose browser.

 The modes run on different engines because `SFSafariViewController` offers no way to intercept
 navigation: Apple keeps the browsing inside it private from the host app. A gated mode
 therefore has to be a `WKWebView`. macOS has no `SFSafariViewController` and always shows a
 `GatedWebView`, following the given mode.

 ## Usage
 ```swift
 .webViewSheet(isPresented: $isShowingArticle, url: articleURL, dismissTitle: "button.done")

 // One sheet for several pages: the item variant builds a fresh sheet per page.
 .webViewSheet(item: $document, url: \.url, dismissTitle: "button.done", title: \.title, allowsBrowsing: .none)
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
    ///   - allowsBrowsing: Which tapped links stay inside the app. Defaults to `.everywhere`.
    func webViewSheet(
        isPresented: Binding<Bool>,
        url: URL,
        dismissTitle: LocalizedStringKey,
        title: LocalizedStringKey? = nil,
        allowsBrowsing: WebBrowsing = .everywhere
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
    ///   - allowsBrowsing: Which tapped links stay inside the app. Defaults to `.everywhere`.
    func webViewSheet<Item: Identifiable>(
        item: Binding<Item?>,
        url: @escaping (Item) -> URL,
        dismissTitle: LocalizedStringKey,
        title: ((Item) -> LocalizedStringKey)? = nil,
        allowsBrowsing: WebBrowsing = .everywhere
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
    let allowsBrowsing: WebBrowsing

    var body: some View {
        #if os(iOS)
        if allowsBrowsing == .everywhere {
            SafariView(url: url)
                .ignoresSafeArea()
        } else {
            GatedSheetContent(url: url, dismissTitle: dismissTitle, title: title, allowsBrowsing: allowsBrowsing)
        }
        #else
        GatedSheetContent(url: url, dismissTitle: dismissTitle, title: title, allowsBrowsing: allowsBrowsing)
        #endif
    }
}

private struct GatedSheetContent: View {
    let url: URL
    let dismissTitle: LocalizedStringKey
    let title: LocalizedStringKey?
    let allowsBrowsing: WebBrowsing

    var body: some View {
        NavigationStack {
            GatedWebView(url.absoluteString, navigationTitle: title, allowsBrowsing: allowsBrowsing)
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

#Preview("Everywhere") {
    @Previewable @State var isPresented = true

    Button("Show Sheet") { isPresented = true }
        .webViewSheet(isPresented: $isPresented, url: URL(string: "https://www.apple.com")!, dismissTitle: "Close")
}

#Preview("On Same Domain") {
    @Previewable @State var isPresented = true

    Button("Show Sheet") { isPresented = true }
        .webViewSheet(isPresented: $isPresented, url: URL(string: "https://www.apple.com/privacy")!, dismissTitle: "Close", title: "Privacy", allowsBrowsing: .onSameDomain)
}

#Preview("None") {
    @Previewable @State var isPresented = true

    Button("Show Sheet") { isPresented = true }
        .webViewSheet(isPresented: $isPresented, url: URL(string: "https://www.apple.com/privacy")!, dismissTitle: "Close", title: "Privacy", allowsBrowsing: .none)
}
