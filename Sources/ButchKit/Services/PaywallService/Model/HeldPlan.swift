//
//  HeldPlan.swift
//  ButchKit
//
//  Created by Leo Heuser on 13.09.26.
//

import Foundation
import StoreKit

/// One subscription status, reduced to what ``PaywallStatus`` and ``SubscriptionPhase`` say about it.
///
/// Plain values rather than StoreKit's status, which has no public initializer: only this way
/// can the choice between several statuses be tested.
struct HeldPlan: Equatable {
    let state: Product.SubscriptionInfo.RenewalState
    let productID: String
    let expirationDate: Date?
    let willAutoRenew: Bool
    /// Whether the current period is the introductory offer. Only ``phase`` reads it.
    var isInTrial = false

    /// The plan the row speaks about, or `nil` once none of them grants access. Family Sharing
    /// can add a second status for the same group, so a paid-up plan wins over one with a
    /// payment problem, then the one that runs longest.
    static func current(in plans: [HeldPlan]) -> HeldPlan? {
        plans
            .filter { $0.state != .expired && $0.state != .revoked }
            .max { $0.rank < $1.rank }
    }

    /// What analytics hears about this plan, or `nil` while a payment problem is open: grace and
    /// billing retry are neither renewing nor canceled, and would blur both slices.
    var phase: SubscriptionPhase? {
        guard state == .subscribed else { return nil }
        return SubscriptionPhase(isInTrial: isInTrial, willAutoRenew: willAutoRenew)
    }

    private var rank: (Int, Date) {
        (state == .subscribed ? 1 : 0, expirationDate ?? .distantPast)
    }
}

extension HeldPlan {
    /// The plan StoreKit's statuses describe, by the same rule for the settings row and analytics.
    static func current(in statuses: [Product.SubscriptionInfo.Status]) -> HeldPlan? {
        current(in: statuses.compactMap(HeldPlan.init))
    }

    /// The plan a StoreKit status describes, or `nil` when its transaction or renewal info did not
    /// pass verification: nothing is shown on data that did not check out.
    init?(_ status: Product.SubscriptionInfo.Status) {
        guard case .verified(let transaction) = status.transaction,
              case .verified(let renewal) = status.renewalInfo
        else { return nil }
        self.init(
            state: status.state,
            productID: transaction.productID,
            expirationDate: transaction.expirationDate,
            willAutoRenew: renewal.willAutoRenew,
            isInTrial: Self.isTrialPeriod(transaction)
        )
    }

    // Transaction.offer replaced offerType in iOS 17.2 and macOS 14.2; the package still supports
    // the releases before, so the deprecated property covers those systems.
    private static func isTrialPeriod(_ transaction: Transaction) -> Bool {
        if #available(iOS 17.2, macOS 14.2, *) {
            transaction.offer?.type == .introductory
        } else {
            transaction.offerType == .introductory
        }
    }
}
