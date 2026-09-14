//
//  SubscriptionDetail.swift
//  ButchKit
//
//  Created by Leo Heuser on 13.09.26.
//

import Foundation
import StoreKit

/// The line under the plan's name in ``PaywallStatusRow``: what happens next with the
/// subscription.
///
/// A plain value rather than StoreKit's own status, because `Product.SubscriptionInfo.Status`
/// has no public initializer: only a value built from its parts can be tested.
enum SubscriptionDetail: Equatable {
    /// Renews on its own on this date.
    case renews(Date)
    /// Auto-renew is off, so access ends on this date.
    case ends(Date)
    /// The last renewal was not paid and the App Store is retrying. Whatever the date, the one
    /// thing the user needs to hear is that the payment needs attention.
    case billingIssue

    /// `nil` where there is nothing to say: access is gone, or StoreKit gave no date.
    init?(state: Product.SubscriptionInfo.RenewalState, willAutoRenew: Bool, expirationDate: Date?) {
        switch state {
        case .inGracePeriod, .inBillingRetryPeriod:
            self = .billingIssue
        case .subscribed:
            guard let expirationDate else { return nil }
            self = willAutoRenew ? .renews(expirationDate) : .ends(expirationDate)
        default:
            return nil
        }
    }
}
