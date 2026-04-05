import Foundation
import Observation

@Observable
final class SubscriptionViewModel {
    var plans: [SubscriptionPlan] = []
    var mySubscription: MySubscriptionResponse? = nil
    var selectedPlanIndex: Int = 1
    var isLoading: Bool = false
    var isPurchasing: Bool = false
    var errorMessage: String? = nil
    var didSubscribe: Bool = false

    private let api = APIClient.shared

    func loadPlans() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: PlansResponse = try await api.request(.listPlans)
            plans = response.plans
            if let yearly = plans.firstIndex(where: { $0.isYearly }) {
                selectedPlanIndex = yearly
            }
        } catch {
            // Fallback plans
            plans = [
                SubscriptionPlan(id: "pro_monthly", name: "Pro Monthly", pricePaise: 29900,
                                 billingCycle: "monthly", savingPct: nil, features: defaultFeatures),
                SubscriptionPlan(id: "pro_annual", name: "Pro Annual", pricePaise: 179900,
                                 billingCycle: "annual", savingPct: 50, features: defaultFeatures),
                SubscriptionPlan(id: "lifetime", name: "Lifetime Access", pricePaise: 349900,
                                 billingCycle: "lifetime", savingPct: nil, features: defaultFeatures)
            ]
            selectedPlanIndex = 1
        }
    }

    func loadMySubscription() async {
        if let response = try? await api.request(Endpoint.mySubscription) as MySubscriptionResponse {
            mySubscription = response
        }
    }

    func subscribe(planId: String) async {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        // In production: StoreKit flow first, then POST to backend with receipt
        // For now: simulate purchase with mock token
        do {
            let response: SubscriptionResponse = try await api.request(
                .createSubscription(
                    provider: "app_store",
                    purchaseToken: "mock_token_\(UUID().uuidString)",
                    planId: planId
                )
            )
            // Refresh user profile to update tier
            if let user: UserBrief = try? await api.request(.getMe) {
                AuthSession.shared.updateUser(user)
            }
            didSubscribe = true
        } catch {
            errorMessage = (error as? LexisError)?.errorDescription ?? error.localizedDescription
        }
    }

    var selectedPlan: SubscriptionPlan? {
        guard selectedPlanIndex < plans.count else { return nil }
        return plans[selectedPlanIndex]
    }

    private var defaultFeatures: [String] {
        ["unlimited_words", "all_packs", "streak_freeze", "no_ads"]
    }
}
