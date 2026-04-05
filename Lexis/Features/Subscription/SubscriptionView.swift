import SwiftUI

struct SubscriptionView: View {
    @State private var vm = SubscriptionViewModel()
    @Environment(\.dismiss) private var dismiss

    private let features: [(icon: String, text: String)] = [
        ("infinity",             "Unlimited daily reviews"),
        ("books.vertical.fill",  "All word packs unlocked"),
        ("flame.fill",           "Streak freeze protection"),
        ("speaker.wave.2.fill",  "Audio pronunciations"),
        ("nosign",               "No ads, ever")
    ]

    var body: some View {
        ZStack {
            LinearGradient.session.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    headerSection

                    // Feature list
                    featuresSection

                    Divider()
                        .background(Color.glassBorder)
                        .padding(.vertical, Spacing.xxl)
                        .padding(.horizontal, Spacing.xl)

                    // Plans
                    plansSection

                    // CTA
                    ctaSection

                    // Footer
                    footerSection

                    Spacer().frame(height: 48)
                }
            }
        }
        .task {
            await vm.loadPlans()
        }
        .onChange(of: vm.didSubscribe) { _, subscribed in
            if subscribed { dismiss() }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Color.glassBorder)
                    .clipShape(Circle())
            }
            .padding(.top, 60)
            .padding(.trailing, Spacing.xl)
        }
        .overlay(alignment: .top) {
            if let msg = vm.errorMessage {
                ErrorToast(message: msg)
                    .padding(.top, 60)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.lg) {
            Spacer().frame(height: 70)

            ZStack {
                Circle()
                    .fill(LinearGradient.streak.opacity(0.18))
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)

                Text("👑")
                    .font(.system(size: 50))
            }

            VStack(spacing: Spacing.sm) {
                Text("vocu Pro")
                    .font(.lexisDisplay2)
                    .foregroundColor(.moonPearl)
                Text("Your premium vocabulary journey")
                    .font(.lexisBody)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.bottom, Spacing.xxl)
    }

    // MARK: - Features

    private var featuresSection: some View {
        VStack(spacing: Spacing.md) {
            ForEach(features, id: \.text) { feature in
                HStack(spacing: Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient.hero.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: feature.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LinearGradient.hero)
                    }
                    Text(feature.text)
                        .font(.lexisBodyM)
                        .foregroundColor(.moonPearl)
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.jadeGreen)
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Plans

    private var plansSection: some View {
        VStack(spacing: Spacing.md) {
            if vm.isLoading {
                ForEach(0..<3, id: \.self) { _ in ShimmerCard(height: 76) }
                    .padding(.horizontal, Spacing.xl)
            } else {
                ForEach(Array(vm.plans.enumerated()), id: \.offset) { i, plan in
                    SubscriptionPlanCard(
                        plan: plan,
                        isSelected: vm.selectedPlanIndex == i,
                        onTap: {
                            withAnimation(.spring(response: 0.3)) {
                                vm.selectedPlanIndex = i
                            }
                        }
                    )
                    .padding(.horizontal, Spacing.xl)
                }
            }
        }
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: Spacing.md) {
            Button {
                Haptics.impact(.medium)
                if let plan = vm.selectedPlan {
                    Task { await vm.subscribe(planId: plan.id) }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if vm.isPurchasing {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    }
                    Text(vm.selectedPlan?.isLifetime == true
                         ? "Get Lifetime Access"
                         : "Start Free Trial")
                }
            }
            .primaryStyle(isLoading: vm.isPurchasing)
            .padding(.horizontal, Spacing.xl)
            .padding(.top, Spacing.xxl)

            Text("Cancel anytime • No hidden fees")
                .font(.lexisCaption)
                .foregroundColor(.textTertiary)
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: Spacing.xl) {
            Button("Restore") {}
                .ghostStyle(color: .textSecondary)
                .font(.lexisCaption)
            Button("Terms") {}
                .ghostStyle(color: .textSecondary)
                .font(.lexisCaption)
            Button("Privacy") {}
                .ghostStyle(color: .textSecondary)
                .font(.lexisCaption)
        }
        .padding(.top, Spacing.lg)
    }
}

// MARK: - Plan Card

struct SubscriptionPlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: Spacing.sm) {
                        Text(plan.name)
                            .font(.lexisH3)
                            .foregroundColor(.moonPearl)

                        if let saving = plan.savingPct, saving > 0 {
                            Text("Save \(saving)%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(LinearGradient.jade)
                                .clipShape(Capsule())
                        }

                        if plan.isYearly {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.amberGlow)
                                .tracking(0.8)
                        }
                    }

                    Text(plan.isLifetime ? "One-time payment" : "Billed \(plan.billingCycle ?? "")")
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.priceDisplay)
                        .font(.lexisH2)
                        .foregroundColor(.moonPearl)
                    if !plan.isLifetime {
                        Text(plan.cycleDisplay)
                            .font(.lexisCaption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .padding(Spacing.lg)
            .background(
                isSelected
                ? AnyView(LinearGradient.hero.opacity(0.15))
                : AnyView(Color.surfaceCard)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(
                        isSelected
                        ? AnyShapeStyle(LinearGradient.hero)
                        : AnyShapeStyle(Color.glassBorder),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
