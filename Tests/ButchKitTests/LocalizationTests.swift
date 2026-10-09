import Foundation
import Testing

/// A word missing from a catalog is not an error anyone sees: the app shows ButchKit's English in
/// the middle of another language. These tests read the catalogs and the code that declares the
/// words, so a gap fails here rather than on a user's screen.
@Suite("Localization")
struct LocalizationTests {
    /// Each component's catalog and the file that declares its words.
    private static let components: [(catalog: String, strings: String)] = [
        ("Services/PaywallService/Paywall.xcstrings", "Services/PaywallService/Model/PaywallStrings.swift"),
        ("General Utility/ExternalPackagesView/ExternalPackages.xcstrings", "General Utility/ExternalPackagesView/ExternalPackagesStrings.swift"),
    ]

    private static let sources = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "../../Sources/ButchKit")
        .standardized

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            struct Localization: Decodable {
                struct StringUnit: Decodable { let value: String }
                let stringUnit: StringUnit
            }
            let localizations: [String: Localization]?
        }
        let sourceLanguage: String
        let strings: [String: Entry]
    }

    private static func catalog(_ path: String) throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: sources.appending(path: path)))
    }

    /// The keys a component declares, read from its `…Strings` file.
    private static func declaredKeys(_ path: String) throws -> Set<String> {
        let code = try String(contentsOf: sources.appending(path: path), encoding: .utf8)
        return Set(code.matches(of: /LocalizedStringResource\("([^"]+)"/).map { String($0.output.1) })
    }

    /// The languages an entry is translated into.
    private static func languages(_ entry: Catalog.Entry) -> Set<String> {
        Set(entry.localizations.map { Array($0.keys) } ?? [])
    }

    private static func placeholders(_ value: String) -> Int {
        value.matches(of: /%(\d+\$)?[@dlf]/).count
    }

    /// A key declared in code but not in the catalog was never extracted, so every language falls
    /// back to English. A key in the catalog but not in code is dead weight for translators.
    @Test("Every declared word is in its catalog, and nothing else", arguments: components)
    func keysMatch(component: (catalog: String, strings: String)) throws {
        let declared = try Self.declaredKeys(component.strings)
        let catalogued = Set(try Self.catalog(component.catalog).strings.keys)
        #expect(!declared.isEmpty)
        #expect(declared.subtracting(catalogued).isEmpty, "Not in the catalog: \(declared.subtracting(catalogued).sorted())")
        #expect(catalogued.subtracting(declared).isEmpty, "Not in code: \(catalogued.subtracting(declared).sorted())")
    }

    /// One language with one word missing shows that word in English.
    @Test("Every word is translated into every language its catalog has", arguments: components)
    func complete(component: (catalog: String, strings: String)) throws {
        let catalog = try Self.catalog(component.catalog)
        let languages = catalog.strings.values.reduce(into: Set<String>()) { $0.formUnion(Self.languages($1)) }
        for (key, entry) in catalog.strings {
            let missing = languages.subtracting(Self.languages(entry))
            #expect(missing.isEmpty, "\(key) is missing \(missing.sorted())")
            for (language, localization) in entry.localizations ?? [:] {
                #expect(!localization.stringUnit.value.isEmpty, "\(key) is empty in \(language)")
            }
        }
    }

    /// A translation that drops or adds a placeholder shows a raw `%@`, or crashes the format.
    @Test("Every translation keeps the source's placeholders", arguments: components)
    func placeholders(component: (catalog: String, strings: String)) throws {
        let catalog = try Self.catalog(component.catalog)
        for (key, entry) in catalog.strings {
            let localizations = entry.localizations ?? [:]
            let source = try #require(localizations[catalog.sourceLanguage], "\(key) has no source value")
            let expected = Self.placeholders(source.stringUnit.value)
            for (language, localization) in localizations {
                #expect(Self.placeholders(localization.stringUnit.value) == expected, "\(key) in \(language)")
            }
        }
    }

    /// The paywall in Japanese next to a licenses list in English would read as a broken app.
    @Test("Every catalog speaks the same languages")
    func sameLanguages() throws {
        let languages = try Self.components.map { component in
            try Self.catalog(component.catalog).strings.values.reduce(into: Set<String>()) { $0.formUnion(Self.languages($1)) }
        }
        #expect(Set(languages).count == 1)
    }
}
