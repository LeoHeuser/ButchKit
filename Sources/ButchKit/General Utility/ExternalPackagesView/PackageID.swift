//
//  PackageID.swift
//  ButchKit
//
//  Created by Leo Heuser on 14.09.26.
//

import Foundation

/// The name an app gives one of its external packages, and the user's switch behind it.
///
/// ``ExternalPackagesView`` turns an optional package off and on under this name, and the rest of
/// the app asks the same name whether it may run the package:
///
/// ```swift
/// extension PackageID {
///     static let telemetryDeck = PackageID("telemetryDeck")
/// }
///
/// guard PackageID.telemetryDeck.isEnabled else { return }
/// ```
///
/// Deliberately not expressible by a string literal. An id written twice can be written
/// differently, and a gate asked under the wrong name answers "enabled" forever: the switch would
/// move and nothing would stop. Declared once as a `static let`, a typo fails to compile instead.
public struct PackageID: Hashable, Sendable {
    public let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Whether the user lets the app run this package.
    ///
    /// `true` until the switch has been turned off, because the switch is an opt-out. Also always
    /// `true` for a package that is not optional, since nothing ever writes its value. Read from
    /// `UserDefaults` on every call, so it is the stored decision and never a stale copy of it.
    public var isEnabled: Bool {
        Self.store.object(forKey: defaultsKey) as? Bool ?? Self.enabledByDefault
    }

    /// On until the user turns it off: the switch is an opt-out. Read by the gate above and by
    /// the switch alike, so the two cannot answer differently for a package nobody has touched.
    static let enabledByDefault = true

    /// Where the decision lives, named once for the gate and the switch. A switch writing to one
    /// store while the gate reads another would move and stop nothing.
    static var store: UserDefaults { .standard }

    /// Prefixed so it cannot collide with a key the app chose for itself.
    var defaultsKey: String {
        "ButchKit.package.\(rawValue).isEnabled"
    }
}
