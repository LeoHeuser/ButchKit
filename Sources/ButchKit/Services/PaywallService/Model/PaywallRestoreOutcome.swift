//
//  PaywallRestoreOutcome.swift
//  ButchKit
//
//  Created by Leo Heuser on 15.09.26.
//

import StoreKit

/// How a restore ended. On the paywall every outcome but ``cancelled`` gets an alert, worded by
/// the app through ``PaywallTexts``; an app that runs ``PaywallService/restorePurchases()`` from
/// its settings does the same with words of its own.
public enum PaywallRestoreOutcome: Sendable, Equatable {
    /// A purchase is back and unlocks the app.
    case restored
    /// The App Store knows no purchase of the app's products for this account.
    case nothingToRestore
    /// The purchase the App Store returned did not pass verification, or the sync failed for a
    /// reason other than the connection.
    case failed
    /// The App Store could not be reached. Apart from ``failed`` because the user can do something
    /// about it, and because it is the usual case right after a reinstall: no local purchases
    /// yet, and no connection to fetch them.
    case offline
    /// The user backed out of the App Store sign-in. Not a failure, so nothing is shown.
    case cancelled

    /// Decides the outcome from what the sync threw and what the entitlements show afterwards.
    ///
    /// A verified entitlement wins over any error: the app is unlocked, so the paywall must not
    /// say otherwise.
    static func decide(syncError: (any Error)?, snapshot: PaywallEntitlementSnapshot) -> PaywallRestoreOutcome {
        if snapshot.strongest != .none {
            return .restored
        }
        if let syncError {
            if case StoreKitError.userCancelled = syncError {
                return .cancelled
            }
            if PaywallPurchaseFailure(syncError) == .network {
                return .offline
            }
            return .failed
        }
        return snapshot.hasUnverified ? .failed : .nothingToRestore
    }
}
