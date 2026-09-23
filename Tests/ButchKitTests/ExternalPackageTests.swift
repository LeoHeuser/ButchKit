import Foundation
import Testing
@testable import ButchKit

/// The switch is a privacy promise: what the user turned off has to stay off, through updates and
/// in every process that asks. Each test stores in a suite of its own, named as if it were an app
/// group, so nothing reaches the test runner's standard defaults unless the test is about them.
@Suite("ExternalPackage")
struct ExternalPackageTests {
    private let suiteName = "design.heuser.ButchKitTests.ExternalPackage.\(UUID().uuidString)"

    /// A name of its own per test, because the migration test writes to the standard defaults,
    /// which the tests running beside it would otherwise migrate from.
    private let rawValue = "sample.\(UUID().uuidString)"

    private func id(_ availability: ExternalPackage.ID.Availability) -> ExternalPackage.ID {
        ExternalPackage.ID(rawValue, availability: availability, appGroupID: suiteName)
    }

    private func store() throws -> UserDefaults {
        try #require(UserDefaults(suiteName: suiteName))
    }

    private func cleanUp() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    /// Every decision on every device is stored under this key. A rename resets them all.
    @Test("The stored key keeps its format")
    func keyFormat() {
        #expect(ExternalPackage.ID("foo", availability: .optOut).defaultsKey == "ButchKit.package.foo.isEnabled")
    }

    @Test("Opt-out is on and opt-in is off until the user decides")
    func defaults() {
        defer { cleanUp() }
        #expect(id(.optOut).isEnabled)
        #expect(!id(.optIn).isEnabled)
    }

    @Test("A stored decision wins over the default")
    func storedDecisionWins() throws {
        defer { cleanUp() }
        let store = try store()
        store.set(false, forKey: id(.optOut).defaultsKey)
        #expect(!id(.optOut).isEnabled)
        store.set(true, forKey: id(.optIn).defaultsKey)
        #expect(id(.optIn).isEnabled)
    }

    /// A package that was optional once and became required in an update. No switch is left to
    /// undo an old `false`, so the gate must not read it.
    @Test("A required package is enabled despite a stored false")
    func requiredIgnoresStoredValue() throws {
        defer { cleanUp() }
        try store().set(false, forKey: id(.required).defaultsKey)
        #expect(id(.required).isEnabled)
    }

    @Test("An id without availability behaves as in ButchKit 2.0")
    @available(*, deprecated)
    func legacyID() {
        let legacy = ExternalPackage.ID("legacy.\(UUID().uuidString)")
        defer { UserDefaults.standard.removeObject(forKey: legacy.defaultsKey) }
        #expect(legacy.isEnabled)
        UserDefaults.standard.set(false, forKey: legacy.defaultsKey)
        #expect(!legacy.isEnabled)
    }

    @Test("Storing the value already held changes nothing")
    func setterIgnoresSameValue() throws {
        defer { cleanUp() }
        #expect(!id(.optOut).setEnabled(true))
        #expect(try store().object(forKey: id(.optOut).defaultsKey) == nil)
    }

    @Test("A real change is stored before it is reported")
    func setterStoresRealChange() {
        defer { cleanUp() }
        #expect(id(.optOut).setEnabled(false))
        #expect(!id(.optOut).isEnabled)
        #expect(id(.optOut).setEnabled(true))
        #expect(id(.optOut).isEnabled)
    }

    /// An app that starts storing in its app group must keep what the user decided before.
    @Test("A decision in the standard defaults moves into the app group")
    func migratesIntoAppGroup() throws {
        let key = id(.optOut).defaultsKey
        UserDefaults.standard.set(false, forKey: key)
        defer {
            UserDefaults.standard.removeObject(forKey: key)
            cleanUp()
        }

        #expect(!id(.optOut).isEnabled)
        #expect(try store().object(forKey: key) as? Bool == false)
    }

    @Test("Ids are equal by name alone")
    func equalityByName() {
        #expect(ExternalPackage.ID("same", availability: .optIn) == ExternalPackage.ID("same", availability: .required))
    }

    @Test("A package is optional when its id is")
    func optionalityFromID() {
        #expect(package(id: id(.optOut)).isOptional)
        #expect(package(id: id(.optIn)).isOptional)
        #expect(!package(id: id(.required)).isOptional)
    }

    @Test("Standard licenses carry their identifier, notice and text")
    func licenses() throws {
        let mit = ExternalPackage.License.mit(copyright: "Copyright (c) 2024 Example Author")
        #expect(mit.identifier == "MIT")
        #expect(mit.copyright == "Copyright (c) 2024 Example Author")
        #expect(try #require(mit.text).contains("shall be included in all copies or substantial portions"))

        #expect(ExternalPackage.License.apache2().identifier == "Apache-2.0")
        #expect(try #require(ExternalPackage.License.apache2().text).hasSuffix("END OF TERMS AND CONDITIONS"))

        let bsd2 = try #require(ExternalPackage.License.bsd2(copyright: "c").text)
        let bsd3 = try #require(ExternalPackage.License.bsd3(copyright: "c").text)
        #expect(bsd2.contains("2. Redistributions in binary form"))
        #expect(!bsd2.contains("3. Neither the name"))
        #expect(bsd3.contains("3. Neither the name"))

        let custom = ExternalPackage.License.custom(name: "Proprietary")
        #expect(custom.identifier == "Proprietary")
        #expect(custom.text == nil)
    }

    @Test("A clean list has no issues")
    func noIssues() {
        let packages = [
            package(id: ExternalPackage.ID("a", availability: .optOut), onEnabledChange: { _ in }),
            package(id: ExternalPackage.ID("b", availability: .required))
        ]
        #expect(ExternalPackage.issues(in: packages).isEmpty)
    }

    @Test("A duplicate id is an issue")
    func duplicateID() {
        let packages = [
            package(id: ExternalPackage.ID("a", availability: .optOut)),
            package(id: ExternalPackage.ID("a", availability: .optOut))
        ]
        #expect(ExternalPackage.issues(in: packages).count == 1)
    }

    @Test("A reaction on a required package is an issue")
    func reactionOnRequired() {
        let packages = [package(id: ExternalPackage.ID("a", availability: .required), onEnabledChange: { _ in })]
        #expect(ExternalPackage.issues(in: packages).count == 1)
    }

    @Test("A deprecated package whose isOptional contradicts its id is an issue")
    @available(*, deprecated)
    func contradictingOptionality() {
        let packages = [
            ExternalPackage(
                id: ExternalPackage.ID("a", availability: .required),
                name: "Sample",
                license: "MIT",
                description: "Sample",
                url: "https://example.com",
                isOptional: true
            )
        ]
        #expect(ExternalPackage.issues(in: packages).count == 1)
    }

    private func package(
        id: ExternalPackage.ID,
        onEnabledChange: (@MainActor @Sendable (Bool) -> Void)? = nil
    ) -> ExternalPackage {
        ExternalPackage(
            id: id,
            name: "Sample",
            license: .mit(copyright: "Copyright (c) 2024 Example Author"),
            description: "Sample",
            url: "https://example.com",
            onEnabledChange: onEnabledChange
        )
    }
}
