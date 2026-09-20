//
//  PaywallEntitlementSnapshot.swift
//  ButchKit
//
//  Created by Leo Heuser on 15.09.26.
//

import StoreKit

/// One pass over `Transaction.currentEntitlements`, reduced to what ``PaywallService/refresh()``
/// and a restore need to know.
struct PaywallEntitlementSnapshot: Sendable, Equatable {
    /// The strongest entitlement among the verified transactions.
    var strongest: PaywallEntitlement = .none
    /// Whether a transaction for one of the configuration's products failed verification. It grants
    /// nothing, but tells a restore that a purchase exists and could not be trusted.
    var hasUnverified = false
    /// The first verified lifetime product listed, which the settings row names. Should the user
    /// own several, it names what they bought as well as any other.
    var lifetimeProductID: String?
    /// Whether that lifetime product is another family member's, shared through Family Sharing.
    var lifetimeIsFamilyShared = false

    /// Folds one transaction in. Pure, so tests feed it without StoreKit. Products the
    /// configuration does not know change nothing, verified or not.
    mutating func add(productID: String, subscriptionGroupID: String?, isVerified: Bool, isFamilyShared: Bool = false, under configuration: PaywallConfiguration) {
        let granted = configuration.entitlement(productID: productID, subscriptionGroupID: subscriptionGroupID)
        guard granted != .none else { return }
        if isVerified {
            if granted == .lifetime, lifetimeProductID == nil {
                lifetimeProductID = productID
                lifetimeIsFamilyShared = isFamilyShared
            }
            strongest = max(strongest, granted)
        } else {
            hasUnverified = true
        }
    }

    /// Reads StoreKit's current entitlements under the configuration.
    static func current(under configuration: PaywallConfiguration) async -> PaywallEntitlementSnapshot {
        var snapshot = PaywallEntitlementSnapshot()
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                snapshot.add(productID: transaction.productID, subscriptionGroupID: transaction.subscriptionGroupID, isVerified: true, isFamilyShared: transaction.ownershipType == .familyShared, under: configuration)
            case .unverified(let transaction, _):
                snapshot.add(productID: transaction.productID, subscriptionGroupID: transaction.subscriptionGroupID, isVerified: false, isFamilyShared: transaction.ownershipType == .familyShared, under: configuration)
            }
            // Nothing outranks a lifetime product, so the rest of the list cannot change the answer.
            if snapshot.strongest == .lifetime { break }
        }
        return snapshot
    }
}
