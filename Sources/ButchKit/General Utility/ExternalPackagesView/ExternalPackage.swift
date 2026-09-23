//
//  ExternalPackage.swift
//  ButchKit
//
//  Created by Leo Heuser on 02.09.26.
//

import Foundation

/// One external package: its name, license, what it does, where its source lives, and whether
/// the user may turn it off. ``ExternalPackagesView`` renders one section per entry, so listing
/// a new package is only ever adding one to the app's list.
///
/// `name` and `license` are not language, so they stay plain strings. `description` is, and the
/// initializer resolves it through `String(localized:)` itself. Without a bundle that lookup
/// runs in `Bundle.main`, the consuming app, so the key is written at the app's call site and
/// lands in the app's catalog like any other string -- ButchKit still names no keys.
public struct ExternalPackage: Identifiable, Sendable {
    public let id: ID
    public let name: String
    /// The license's short name, such as `MIT`.
    public let license: String
    /// The copyright notice, shown above ``licenseText``.
    public let copyright: String?
    /// The full license text, shown on the package's own page.
    public let licenseText: String?
    public let description: String
    /// Where the package's source lives. `nil` when the address the app handed in is malformed,
    /// which fails an assertion in a debug build and leaves the link out in a release build.
    public let url: URL?

    /// A line under the package's switch, such as that turning it off takes full effect at the
    /// next launch. Only shown with the switch.
    public let note: LocalizedStringResource?

    /// Whether the user may turn the package off, which puts a switch under it. Decided by the
    /// id's ``ID/availability``.
    public var isOptional: Bool {
        legacyIsOptional ?? (id.availability.map { $0 != .required } ?? false)
    }

    /// What the deprecated initializer was told, for an id that does not know its availability.
    private let legacyIsOptional: Bool?

    /// What the app does the moment the user flips that switch: start the package when it turns
    /// on, clean up after it when it turns off.
    ///
    /// ```swift
    /// onEnabledChange: { isEnabled in
    ///     if isEnabled {
    ///         Analytics.start()
    ///     } else {
    ///         Analytics.stop()
    ///         Analytics.deleteCache()
    ///     }
    /// }
    /// ```
    ///
    /// What it promises:
    /// - It runs on the main actor, so it can call anything the app's own code can.
    /// - It runs once per flip by the user, and only when the value really changed.
    /// - The new value is already stored when it runs, so ``ID/isEnabled`` agrees with it.
    /// - It does not run at launch. Whatever starts the package then reads ``ID/isEnabled``.
    ///
    /// Declared on the package rather than handed to the view, so every place that shows the
    /// switch gets the same reaction and none of them can forget to wire it. The app's array of
    /// packages is usually a static constant, so this reaches static API, such as an SDK's own
    /// entry points, rather than an instance the app holds in its state.
    public let onEnabledChange: (@MainActor @Sendable (Bool) -> Void)?

    /// Creates a package.
    ///
    /// ```swift
    /// ExternalPackage(
    ///     id: .analytics,
    ///     name: "Example Analytics",
    ///     license: .mit(copyright: "Copyright (c) 2024 Example Author"),
    ///     description: "text.packages.analytics.description",
    ///     url: "https://example.com/analytics",
    ///     onEnabledChange: { Analytics.setEnabled($0) }
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - id: The package's id, which also says whether the user may turn it off.
    ///   - name: The package's name, as its authors write it.
    ///   - license: The license, with the copyright notice the package states.
    ///   - description: What the app uses the package for, as a key in the app's catalog.
    ///   - url: Where the source lives. A literal the app writes, so a malformed one is a typo:
    ///     it fails an assertion in a debug build, and the page shows no link in a release build.
    ///   - note: A line under the switch. Ignored for a required package, which has none.
    ///   - onEnabledChange: The reaction to the switch. Only for an optional package.
    public init(
        id: ID,
        name: String,
        license: License,
        description: String.LocalizationValue,
        url: String,
        note: LocalizedStringResource? = nil,
        onEnabledChange: (@MainActor @Sendable (Bool) -> Void)? = nil
    ) {
        assert(id.availability != nil, "\(name): declare the availability on its ExternalPackage.ID.")
        self.init(
            id: id,
            name: name,
            license: license,
            description: description,
            url: url,
            note: note,
            legacyIsOptional: nil,
            onEnabledChange: onEnabledChange
        )
    }

    /// Creates a package whose optionality is decided here rather than on its id, as in
    /// ButchKit 2.0.
    @available(*, deprecated, message: "Declare the availability on the id, and use init(id:name:license:description:url:note:onEnabledChange:).")
    public init(
        id: ID,
        name: String,
        license: String,
        description: String.LocalizationValue,
        url: String,
        isOptional: Bool = false,
        onEnabledChange: (@MainActor @Sendable (Bool) -> Void)? = nil
    ) {
        self.init(
            id: id,
            name: name,
            license: .custom(name: license),
            description: description,
            url: url,
            note: nil,
            legacyIsOptional: isOptional,
            onEnabledChange: onEnabledChange
        )
    }

    private init(
        id: ID,
        name: String,
        license: License,
        description: String.LocalizationValue,
        url: String,
        note: LocalizedStringResource?,
        legacyIsOptional: Bool?,
        onEnabledChange: (@MainActor @Sendable (Bool) -> Void)?
    ) {
        self.id = id
        self.name = name
        self.license = license.identifier
        self.copyright = license.copyright
        self.licenseText = license.text
        self.description = String(localized: description)
        self.url = URL(string: url)
        self.note = note
        self.legacyIsOptional = legacyIsOptional
        self.onEnabledChange = onEnabledChange
        assert(self.url != nil, "\(name): \"\(url)\" is not a valid URL.")
    }

    /// Every mistake in a list of packages that would otherwise only show on a device, each as a
    /// sentence naming the package. Empty for a list without any.
    ///
    /// Call it once in the app's tests, so a mistake fails the build rather than the settings:
    ///
    /// ```swift
    /// @Test func externalPackagesAreValid() {
    ///     #expect(ExternalPackage.issues(in: ExternalPackage.all).isEmpty)
    /// }
    /// ```
    ///
    /// ``ExternalPackagesView`` asserts the same in a debug build, so the first preview shows it too.
    public static func issues(in packages: [ExternalPackage]) -> [String] {
        var issues: [String] = []
        var seen: Set<ID> = []
        for package in packages {
            if !seen.insert(package.id).inserted {
                issues.append("\(package.name): the id \"\(package.id.rawValue)\" is used by more than one package.")
            }
            if package.url == nil {
                issues.append("\(package.name): the source address is not a valid URL.")
            }
            if package.onEnabledChange != nil, !package.isOptional {
                issues.append("\(package.name): a required package has no switch, so onEnabledChange never runs.")
            }
            if let legacyIsOptional = package.legacyIsOptional, let availability = package.id.availability,
               legacyIsOptional != (availability != .required) {
                issues.append("\(package.name): isOptional contradicts the availability of its id.")
            }
            if package.legacyIsOptional == nil, package.id.availability == nil {
                issues.append("\(package.name): its id declares no availability.")
            }
        }
        return issues
    }
}
