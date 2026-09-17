//
//  PaywallEntitlement.swift
//  ButchKit
//
//  Created by Leo Heuser on 15.09.26.
//

/// What unlocks the app, by strength.
///
/// One answer for every gate: a subscription in the configured group and the optional lifetime
/// product both end in `PaywallService.hasAccess` being `true`; only the settings row
/// reads the case to say which. Ordered so that several transactions reduce to the strongest one
/// with `max()`: a lifetime purchase is never overwritten by a subscription that happens to be
/// listed after it.
public enum PaywallEntitlement: String, Sendable, Comparable {
    case none
    case subscription
    case lifetime

    private var rank: Int {
        switch self {
        case .none: 0
        case .subscription: 1
        case .lifetime: 2
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rank < rhs.rank
    }
}
