//
//  PaywallRestoreOutcome.swift
//  ButchKit
//
//  Created by Leo Heuser on 15.09.26.
//

import StoreKit

/// How a restore from the paywall ended. Every outcome but ``cancelled`` gets an
/// alert, worded by the app through ``PaywallTexts``.
enum PaywallRestoreOutcome: Sendable, Equatable {
    /// A purchase is back and unlocks the app.
    case restored
    /// The App Store knows no purchase of the app's products for this account.
    case nothingToRestore
    /// The App Store could not be reached, or the purchase it returned did not pass verification.
    case failed
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
            return .failed
        }
        return snapshot.hasUnverified ? .failed : .nothingToRestore
    }
}
