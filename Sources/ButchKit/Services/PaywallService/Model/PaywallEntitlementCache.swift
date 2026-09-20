//
//  PaywallEntitlementCache.swift
//  ButchKit
//
//  Created by Leo Heuser on 20.09.26.
//

import Foundation

/// The last entitlement StoreKit confirmed, as ``PaywallService`` left it in `UserDefaults`.
///
/// The service reads it at launch, so a paying user sees no paywall flash. With an app group it is
/// also how code in another process gets the answer: a widget, a share extension or an App Intent
/// cannot reach the service, but reads this.
///
/// ```swift
/// let entitlement = PaywallEntitlementCache(appGroupID: "group.design.heuser.App").entitlement
/// ```
///
/// `nil` means nothing is known yet, never "does not pay": the app has not run since the install,
/// or StoreKit has not answered it. The value is as old as the app's last entitlement check, so a
/// subscription that ran out since still reads as one until the app is opened again. It is a plain
/// `UserDefaults` value the user can edit, so gate nothing on it that costs money to give away.
///
/// An extension that does not link ButchKit reads the same thing by hand: the string under ``key``
/// in the group's `UserDefaults`, one of `none`, `subscription` or `lifetime`.
public struct PaywallEntitlementCache: Sendable {
    /// Where the entitlement's raw value is kept. Stable, extensions read it by name.
    public static let key = "design.heuser.ButchKit.paywall.entitlement"
    /// The cache before the lifetime product, one Bool in the standard defaults. Read so a
    /// subscriber updating the app sees no paywall flash; every write goes to ``key``.
    static let legacyKey = "design.heuser.ButchKit.paywall.hasSubscription"

    /// The app group the cache lives in, `nil` for the app's own defaults.
    public let appGroupID: String?

    /// - Parameter appGroupID: The same group as in the app's ``PaywallConfiguration``.
    public init(appGroupID: String? = nil) {
        self.appGroupID = appGroupID
    }

    /// The last confirmed entitlement, or `nil` when none was ever written.
    public var entitlement: PaywallEntitlement? {
        // The standard defaults second: an app that adopts a group keeps the answer it cached
        // before, until the first write lands in the group.
        Self.entitlement(in: defaults)
            ?? Self.entitlement(in: .standard)
            ?? (UserDefaults.standard.bool(forKey: Self.legacyKey) ? .subscription : nil)
    }

    func write(_ entitlement: PaywallEntitlement) {
        defaults.set(entitlement.rawValue, forKey: Self.key)
    }

    // Looked up on every access: `UserDefaults` is not `Sendable`, so it is not stored. A suite
    // name is refused only for the app's own domain; a group the app is not entitled to still
    // yields a store, one nothing else can read, so check a group that seems not to work against
    // the entitlement rather than expecting a fallback here.
    private var defaults: UserDefaults {
        appGroupID.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    private static func entitlement(in defaults: UserDefaults) -> PaywallEntitlement? {
        defaults.string(forKey: key).flatMap(PaywallEntitlement.init(rawValue:))
    }
}
