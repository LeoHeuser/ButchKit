//
//  HeldPlan.swift
//  ButchKit
//
//  Created by Leo Heuser on 13.09.26.
//

import Foundation
import StoreKit

/// One subscription status, reduced to what ``PaywallStatusRow`` shows about it.
///
/// Plain values rather than StoreKit's status, which has no public initializer: only this way
/// can the choice between several statuses be tested.
struct HeldPlan: Equatable {
    let state: Product.SubscriptionInfo.RenewalState
    let productID: String
    let expirationDate: Date?
    let willAutoRenew: Bool

    /// The plan the row speaks about, or `nil` once none of them grants access. Family Sharing
    /// can add a second status for the same group, so a paid-up plan wins over one with a
    /// payment problem, then the one that runs longest.
    static func current(in plans: [HeldPlan]) -> HeldPlan? {
        plans
            .filter { $0.state != .expired && $0.state != .revoked }
            .max { $0.rank < $1.rank }
    }

    private var rank: (Int, Date) {
        (state == .subscribed ? 1 : 0, expirationDate ?? .distantPast)
    }
}
