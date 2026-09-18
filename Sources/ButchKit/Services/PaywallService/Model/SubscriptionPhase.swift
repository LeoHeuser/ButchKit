//
//  SubscriptionPhase.swift
//  ButchKit
//
//  Created by Leo Heuser on 17.09.26.
//

/// Where an active subscriber stands: still in the free trial or paying, and whether the
/// subscription renews or was already canceled and is running out.
///
/// The raw values are what an app sends to analytics, so they never change.
public enum SubscriptionPhase: String, Sendable {
    /// In the introductory offer, and it will convert into a paid period.
    case trialRenewing
    /// In the introductory offer with auto-renew off: the trial was canceled.
    case trialCanceled
    /// In a paid period that renews.
    case paidRenewing
    /// In a paid period with auto-renew off: access ends with this period.
    case paidCanceled

    init(isInTrial: Bool, willAutoRenew: Bool) {
        switch (isInTrial, willAutoRenew) {
        case (true, true): self = .trialRenewing
        case (true, false): self = .trialCanceled
        case (false, true): self = .paidRenewing
        case (false, false): self = .paidCanceled
        }
    }
}
