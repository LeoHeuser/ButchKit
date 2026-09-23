//
//  ExternalPackageID.swift
//  ButchKit
//
//  Created by Leo Heuser on 14.09.26.
//

import Foundation

extension ExternalPackage {
    /// The name an app gives one of its external packages, whether the user may turn it off, and
    /// the user's switch behind it.
    ///
    /// ``ExternalPackagesView`` turns an optional package off and on under this name, and the
    /// rest of the app asks the same name whether it may run the package:
    ///
    /// ```swift
    /// extension ExternalPackage.ID {
    ///     nonisolated static let analytics = ExternalPackage.ID("analytics", availability: .optOut)
    /// }
    ///
    /// guard ExternalPackage.ID.analytics.isEnabled else { return }
    /// ```
    ///
    /// `nonisolated` matters in a project that sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`,
    /// which new Xcode projects do: without it the constant is main-actor isolated, and code off
    /// the main actor cannot ask the gate.
    ///
    /// Deliberately not expressible by a string literal. An id written twice can be written
    /// differently, and a gate asked under the wrong name answers its default forever: the switch
    /// would move and nothing would stop. Declared once as a `static let`, a typo fails to compile
    /// instead.
    ///
    /// Equal by ``rawValue`` alone: the name is what the decision is stored under, so two ids with
    /// one name are one package.
    public struct ID: Hashable, Sendable {
        /// Whether the user may turn a package off, and what it is before they touch the switch.
        ///
        /// Declared on the id rather than on the package, because the gate needs it: a package
        /// that became required in an update answers `true` even where an earlier switch stored
        /// `false`, since no switch is left to undo it.
        public enum Availability: Hashable, Sendable {
            /// The app cannot run without it. No switch, and the gate always answers `true`.
            case required
            /// A switch, on until the user turns it off. Fits a package that collects nothing
            /// personal, such as privacy-friendly analytics.
            case optOut
            /// A switch, off until the user turns it on. Fits a package that may only run with
            /// consent, such as crash reporting with device data.
            case optIn
        }

        public let rawValue: String

        /// `nil` only for an id created with the deprecated ``init(_:)``, which leaves the
        /// decision to the package and keeps the behavior of ButchKit 2.0.
        public let availability: Availability?

        /// The app group the decision is stored in, so an app extension can ask the gate too.
        /// `nil` stores it in the app's standard defaults, which only the app itself sees.
        public let appGroupID: String?

        /// - Parameters:
        ///   - rawValue: The package's name in the stored key. Never rename it: a new name starts
        ///     every user at the default again.
        ///   - availability: Whether the user may turn the package off, and its state until then.
        ///   - appGroupID: The app group shared with the app's extensions, such as
        ///     `"group.com.example.App"`. A decision stored before the app named a group is moved
        ///     into it the first time the app asks the gate.
        public init(_ rawValue: String, availability: Availability, appGroupID: String? = nil) {
            self.rawValue = rawValue
            self.availability = availability
            self.appGroupID = appGroupID
        }

        /// An id that leaves optionality to the package, as in ButchKit 2.0.
        ///
        /// Its gate cannot tell a required package from an optional one, so a package that was
        /// optional once stays off for a user who turned it off, even after it became required.
        @available(*, deprecated, message: "Declare the availability on the id: ID(_:availability:appGroupID:).")
        public init(_ rawValue: String) {
            self.rawValue = rawValue
            self.availability = nil
            self.appGroupID = nil
        }

        public static func == (lhs: ID, rhs: ID) -> Bool {
            lhs.rawValue == rhs.rawValue
        }

        public func hash(into hasher: inout Hasher) {
            hasher.combine(rawValue)
        }

        /// Whether the user lets the app run this package.
        ///
        /// Always `true` for a required package. For an optional one, the stored decision, or
        /// ``enabledByDefault`` while the user has not touched the switch. Read from `UserDefaults`
        /// on every call, so it is the stored decision and never a stale copy of it.
        ///
        /// With an ``appGroupID``, the first call also moves a decision still stored in the app's
        /// standard defaults into the group. Ask it once at launch, and the extensions see the
        /// user's decision from then on.
        public var isEnabled: Bool {
            guard availability != .required else { return true }
            migrateIntoAppGroup()
            return store.object(forKey: defaultsKey) as? Bool ?? enabledByDefault
        }

        /// What the switch shows and the gate answers until the user touches the switch. Read by
        /// both, so the two cannot answer differently for a package nobody has touched.
        var enabledByDefault: Bool {
            availability != .optIn
        }

        /// Where the decision lives, named once for the gate and the switch. A switch writing to
        /// one store while the gate reads another would move and stop nothing.
        var store: UserDefaults {
            appGroupID.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        }

        /// Prefixed so it cannot collide with a key the app chose for itself. It still says
        /// `package` rather than the type's name on purpose: a renamed key would reset every
        /// decision already stored on a device.
        var defaultsKey: String {
            "ButchKit.package.\(rawValue).isEnabled"
        }

        /// Stores the user's decision, the one place that writes it.
        ///
        /// - Returns: Whether the value changed. Storing the value already held does nothing, so a
        ///   reaction to the change runs only for a real one.
        @discardableResult
        func setEnabled(_ isEnabled: Bool) -> Bool {
            guard isEnabled != self.isEnabled else { return false }
            store.set(isEnabled, forKey: defaultsKey)
            return true
        }

        /// Copies a decision from the standard defaults into the app group, once. It stays in
        /// the standard defaults too, so a build without the group still reads it.
        private func migrateIntoAppGroup() {
            guard appGroupID != nil else { return }
            let store = store
            guard store !== UserDefaults.standard,
                  store.object(forKey: defaultsKey) == nil,
                  let stored = UserDefaults.standard.object(forKey: defaultsKey) as? Bool
            else { return }
            store.set(stored, forKey: defaultsKey)
        }
    }
}
