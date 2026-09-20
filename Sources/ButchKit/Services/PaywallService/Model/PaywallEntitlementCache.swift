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
    /// Where the app kept the answer before it adopted ButchKit, see ``PaywallConfiguration/LegacyCache``.
    let legacy: PaywallConfiguration.LegacyCache?

    /// - Parameter appGroupID: The same group as in the app's ``PaywallConfiguration``.
    public init(appGroupID: String? = nil) {
        self.init(appGroupID: appGroupID, legacy: nil)
    }

    init(appGroupID: String?, legacy: PaywallConfiguration.LegacyCache?) {
        self.appGroupID = appGroupID
        self.legacy = legacy
    }

    /// The last confirmed entitlement, or `nil` when none was ever written.
    public var entitlement: PaywallEntitlement? {
        // The standard defaults second: an app that adopts a group keeps the answer it cached
        // before, until the first write lands in the group.
        Self.entitlement(in: defaults)
            ?? Self.entitlement(in: .standard)
            ?? (UserDefaults.standard.bool(forKey: Self.legacyKey) ? .subscription : nil)
            ?? legacyEntitlement
    }

    /// What the app's own purchase code left behind, read until ButchKit has written an answer of
    /// its own. Only ever a `true`: a `false` there says as little as a missing key.
    private var legacyEntitlement: PaywallEntitlement? {
        guard let legacy else { return nil }
        return Self.store(legacy.suiteName).bool(forKey: legacy.key) ? .subscription : nil
    }

    /// What ButchKit itself last wrote, in its own store and without the fallbacks ``entitlement``
    /// reads. The service seeds its write dedupe from this, so an answer that came from an older
    /// store or from the app's own key is still written into this one, once StoreKit confirms it.
    var ownEntitlement: PaywallEntitlement? {
        Self.entitlement(in: defaults)
    }

    func write(_ entitlement: PaywallEntitlement) {
        defaults.set(entitlement.rawValue, forKey: Self.key)
    }

    /// An Ask to Buy purchase waiting for a parent. Kept next to the entitlement because the
    /// approval usually arrives after the app was quit, and the funnel should still close with
    /// the source it opened with.
    var pendingPurchase: PaywallPendingPurchase? {
        defaults.data(forKey: Self.pendingPurchaseKey).flatMap { try? JSONDecoder().decode(PaywallPendingPurchase.self, from: $0) }
    }

    func write(pendingPurchase: PaywallPendingPurchase?) {
        if let pendingPurchase, let data = try? JSONEncoder().encode(pendingPurchase) {
            defaults.set(data, forKey: Self.pendingPurchaseKey)
        } else {
            defaults.removeObject(forKey: Self.pendingPurchaseKey)
        }
    }

    static let pendingPurchaseKey = "design.heuser.ButchKit.paywall.pendingPurchase"

    // Looked up on every access: `UserDefaults` is not `Sendable`, so it is not stored. A suite
    // name is refused only for the app's own domain; a group the app is not entitled to still
    // yields a store, one nothing else can read, so check a group that seems not to work against
    // the entitlement rather than expecting a fallback here.
    private var defaults: UserDefaults {
        Self.store(appGroupID)
    }

    private static func store(_ suiteName: String?) -> UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    private static func entitlement(in defaults: UserDefaults) -> PaywallEntitlement? {
        defaults.string(forKey: key).flatMap(PaywallEntitlement.init(rawValue:))
    }
}

/// An Ask to Buy purchase that waits for approval: what was asked for, from where, and when.
struct PaywallPendingPurchase: Codable, Equatable {
    let source: String
    let productID: String
    let date: Date

    /// Apple drops a request the family organizer has not answered within 24 hours. Twice that,
    /// so an approval given at the last minute and delivered late still counts, while a request
    /// long gone cannot turn a later, ordinary purchase into an "approval".
    static let lifetime: TimeInterval = 48 * 60 * 60

    func isCurrent(at now: Date) -> Bool {
        now.timeIntervalSince(date) < Self.lifetime
    }
}
