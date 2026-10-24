import Foundation
import Testing

/// A word missing from a catalog is not an error anyone sees: the app shows a raw key, or ButchKit's
/// English in the middle of another language. These tests read the catalogs and the code that looks
/// the words up, so a gap fails here rather than on a user's screen.
/// At file scope, because the suite's own trait cannot reach into the suite.
private let packageSources = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .appending(path: "../../Sources/ButchKit")
    .standardized

// A device has no copy of the path the tests were built from, so the suite runs on a Mac or a
// simulator only, as in CI.
@Suite(
    "Localization",
    .enabled(
        if: FileManager.default.fileExists(atPath: packageSources.path(percentEncoded: false)),
        "Reads the package's sources, which only a Mac or a simulator has on disk"
    )
)
struct LocalizationTests {
    /// Each component's catalog, named after its table, in the component's folder.
    private static let components = [
        "Services/PaywallService/Paywall.xcstrings",
        "General Utility/ExternalPackagesView/ExternalPackages.xcstrings",
    ]

    private static let sources = packageSources

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

    /// The table a catalog compiles to.
    private static func table(_ catalog: String) -> String {
        URL(filePath: catalog).deletingPathExtension().lastPathComponent
    }

    /// Every Swift file in the catalog's component folder.
    private static func code(_ catalog: String) throws -> String {
        let folder = sources.appending(path: catalog).deletingLastPathComponent()
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
        return try (files?.allObjects as? [URL] ?? [])
            .filter { $0.pathExtension == "swift" }
            .map { try String(contentsOf: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    /// The keys a component looks up in its table, with each interpolation as the `%@` Xcode
    /// extracts it as.
    private static func usedKeys(_ catalog: String) throws -> Set<String> {
        let table = table(catalog)
        let lookup = try Regex(#""((?:[^"\\]|\\.)*)",\s*(?:tableName|table): ""# + table + #"""#)
        return Set(try code(catalog).matches(of: lookup).map { match in
            let key = String(match.output[1].substring ?? "")
            return key.replacing(/\\\((?:[^()]|\([^()]*\))*\)/, with: "%@")
        })
    }

    /// The languages an entry is translated into.
    private static func languages(_ entry: Catalog.Entry) -> Set<String> {
        Set(entry.localizations.map { Array($0.keys) } ?? [])
    }

    private static func placeholders(_ value: String) -> Int {
        value.matches(of: /%(\d+\$)?[@dlf]/).count
    }

    /// A key looked up but not in the catalog shows as the raw key. A key in the catalog but never
    /// looked up is dead weight for translators.
    @Test("Every word looked up is in its catalog, and nothing else", arguments: components)
    func keysMatch(catalog path: String) throws {
        let declared = try Self.usedKeys(path)
        let catalogued = Set(try Self.catalog(path).strings.keys)
        #expect(!declared.isEmpty)
        #expect(declared.subtracting(catalogued).isEmpty, "Not in the catalog: \(declared.subtracting(catalogued).sorted())")
        #expect(catalogued.subtracting(declared).isEmpty, "Not in code: \(catalogued.subtracting(declared).sorted())")
    }

    /// Without ButchKit's bundle, a lookup searches the app's catalogs and shows the raw key.
    @Test("Every lookup names ButchKit's bundle", arguments: components)
    func bundle(catalog path: String) throws {
        let table = Self.table(path)
        let code = try Self.code(path)
        let lookups = try code.matches(of: Regex(#"(?:tableName|table): ""# + table + #"""#)).count
        let withBundle = try code.matches(of: Regex(#"(?:tableName|table): ""# + table + #"", bundle: \.module"#)).count
        #expect(lookups > 0)
        #expect(lookups == withBundle)
    }

    /// One language with one word missing shows that word in English.
    @Test("Every word is translated into every language its catalog has", arguments: components)
    func complete(catalog path: String) throws {
        let catalog = try Self.catalog(path)
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
    func placeholders(catalog path: String) throws {
        let catalog = try Self.catalog(path)
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
        let languages = try Self.components.map { path in
            try Self.catalog(path).strings.values.reduce(into: Set<String>()) { $0.formUnion(Self.languages($1)) }
        }
        #expect(Set(languages).count == 1)
    }
}
