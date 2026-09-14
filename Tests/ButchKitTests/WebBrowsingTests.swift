import Foundation
import Testing
@testable import ButchKit

@Suite("WebBrowsing")
struct WebBrowsingTests {
    private let start = URL(string: "https://www.apple.com/iphone/")!

    /// A tap on `link` while the starting page is shown.
    private func keeps(_ browsing: WebBrowsing, _ link: String) -> Bool {
        browsing.keepsInApp(URL(string: link)!, startURL: start, currentURL: start)
    }

    @Test("Keeps the starting domain, with or without www, and its subdomains", arguments: [
        "https://www.apple.com/mac/",
        "https://apple.com/mac/",
        "https://WWW.Apple.com/mac/",
        "https://support.apple.com/"
    ])
    func sameDomainKeeps(link: String) {
        #expect(keeps(.onSameDomain, link))
    }

    /// `evilapple.com` ends in `apple.com` without being part of it.
    @Test("Hands other domains to the browser, look-alikes included", arguments: [
        "https://www.google.de/",
        "https://evilapple.com/",
        "https://apple.com.example.org/"
    ])
    func sameDomainHandsOff(link: String) {
        #expect(!keeps(.onSameDomain, link))
    }

    @Test("Hands every other page to the browser, even on the same website", arguments: [
        "https://www.apple.com/mac/",
        "https://www.apple.com/iphone/",
        "https://www.apple.com/mac/#design"
    ])
    func noneHandsOff(link: String) {
        #expect(!keeps(.none, link))
    }

    /// A table of contents on a legal text must keep working in the strictest mode.
    @Test("Keeps an anchor jump on the page being shown in every mode", arguments: [
        WebBrowsing.none, .onSameDomain, .everywhere
    ])
    func anchorKeeps(browsing: WebBrowsing) {
        #expect(keeps(browsing, "https://www.apple.com/iphone/#specs"))
    }

    @Test("Keeps every link when browsing is allowed everywhere")
    func everywhereKeeps() {
        #expect(keeps(.everywhere, "https://www.google.de/"))
    }
}
