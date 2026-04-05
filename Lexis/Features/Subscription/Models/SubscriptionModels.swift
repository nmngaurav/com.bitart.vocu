import Foundation

// MARK: - Plans Response

struct PlansResponse: Decodable {
    let plans: [SubscriptionPlan]
}

struct SubscriptionPlan: Decodable, Identifiable {
    let id: String
    let name: String
    let pricePaise: Int
    let billingCycle: String?
    let savingPct: Int?
    let features: [String]?

    var priceDisplay: String {
        let amount = Double(pricePaise) / 100.0
        if amount == amount.rounded() {
            return "₹\(Int(amount))"
        }
        return String(format: "₹%.2f", amount)
    }

    var cycleDisplay: String {
        switch billingCycle {
        case "monthly":  return "/ month"
        case "annual":   return "/ year"
        default:         return ""
        }
    }

    var isLifetime: Bool { billingCycle == nil || billingCycle == "lifetime" }
    var isYearly: Bool   { billingCycle == "annual" }
    var isMonthly: Bool  { billingCycle == "monthly" }
}

// MARK: - My Subscription

struct MySubscriptionResponse: Decodable {
    let status: String
    let tier: String
    let planId: String?
    let provider: String?
    let currentPeriodEnd: String?
    let willRenew: Bool?
}

// MARK: - Create Subscription

struct SubscriptionResponse: Decodable {
    let subscriptionId: Int?
    let status: String
    let tier: String
    let currentPeriodEnd: String?
}
