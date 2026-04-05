import SwiftUI

struct SoftPaywallAuthView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @State private var vm = AuthViewModel()
    @State private var plans: [SubscriptionPlan] = []
    @State private var selectedPlanIndex: Int = 1
    @State private var showEmailSheet = false
    @State private var showGoogleEmailSheet = false
    @State private var isLoadingPlans = false
    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            Color.inkBlack.ignoresSafeArea()
            ParticleFieldView(tintColor: .moonPearl)
                .ignoresSafeArea()
                .opacity(0.38)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    if AuthSession.shared.isAuthenticated {
                        HStack {
                            Button {
                                coordinator.navigateToMain()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("Back to vocu")
                                }
                                .font(.lexisBodySm)
                                .foregroundColor(.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.xl)
                        .padding(.bottom, Spacing.md)
                    }

                    // Header
                    headerSection
                        .slideInFromBottom(delay: 0.05, visible: hasAppeared)

                    // Pricing cards
                    pricingSection
                        .slideInFromBottom(delay: 0.15, visible: hasAppeared)

                    Divider()
                        .background(Color.glassBorder)
                        .padding(.vertical, Spacing.lg)
                        .padding(.horizontal, Spacing.xl)
                        .slideInFromBottom(delay: 0.25, visible: hasAppeared)

                    authSection
                        .slideInFromBottom(delay: 0.35, visible: hasAppeared)

                    Spacer().frame(height: 40)
                }
                .padding(.top, 16)
            }
        }
        .task { 
            await loadPlans() 
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailAuthSheet(vm: vm) {
                coordinator.navigateToMain()
            }
        }
        .sheet(isPresented: $showGoogleEmailSheet) {
            GoogleEmailSheet { email in
                showGoogleEmailSheet = false
                Task { await vm.signInWithGoogleEmail(email) }
            }
        }
        .onChange(of: vm.isLoading) { _, loading in
            if !loading && AuthSession.shared.isAuthenticated {
                coordinator.navigateToMain()
            }
        }
        .overlay(alignment: .top) {
            if let msg = vm.errorMessage {
                ErrorToast(message: msg)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4), value: vm.errorMessage)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(LinearGradient.hero.opacity(0.18))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                Image(systemName: "crown.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(LinearGradient.hero)
            }

            VStack(spacing: Spacing.sm) {
                Text("vocu")
                    .font(.lexisDisplay2)
                    .foregroundColor(.moonPearl)

                Text("Master words that matter")
                    .font(.lexisBody)
                    .foregroundColor(.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.lg)
    }

    // MARK: - Pricing

    @ViewBuilder
    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Choose your plan")
                .font(.lexisBodyM)
                .foregroundColor(.textSecondary)
                .padding(.horizontal, Spacing.xl)

            if isLoadingPlans {
                VStack(spacing: Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in ShimmerCard(height: 64) }
                }
                .padding(.horizontal, Spacing.xl)
            } else if plans.isEmpty {
                // Hardcoded fallback if API unavailable
                VStack(spacing: Spacing.md) {
                    ForEach(Array(fallbackPlans.enumerated()), id: \.offset) { i, plan in
                        PricingCard(plan: plan, isSelected: selectedPlanIndex == i) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedPlanIndex = i
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
            } else {
                VStack(spacing: Spacing.md) {
                    ForEach(Array(plans.enumerated()), id: \.offset) { i, plan in
                        PricingCard(plan: plan, isSelected: selectedPlanIndex == i) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedPlanIndex = i
                            }
                        }
                    }
                }
                .padding(.horizontal, Spacing.xl)
            }
        }
    }

    // MARK: - Auth (parallel providers → or → guest)

    private var authSection: some View {
        VStack(spacing: Spacing.lg) {
            Text("Continue with")
                .font(.lexisCaption)
                .foregroundColor(.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.xl)

            LexisAuthProviderRow(
                vm: vm,
                onGoogle: { showGoogleEmailSheet = true },
                onEmail: { showEmailSheet = true }
            )

            HStack {
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
                Text("or")
                    .font(.lexisCaption)
                    .foregroundColor(.textTertiary)
                    .padding(.horizontal, Spacing.sm)
                Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            }
            .padding(.horizontal, Spacing.xl)

            Button {
                Haptics.impact(.light)
                Task { await vm.continueAsGuest() }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Continue as Guest")
                }
            }
            .font(.lexisBodyM)
            .fontWeight(.semibold)
            .foregroundColor(.moonPearl)
            .padding(.vertical, Spacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.cobaltBlue.opacity(0.45), lineWidth: 1)
            )
            .padding(.horizontal, Spacing.xl)
            .disabled(vm.isLoading)
            .accessibilityLabel("Continue as guest")
        }
    }

    // MARK: - Load Plans

    private func loadPlans() async {
        isLoadingPlans = true
        defer { isLoadingPlans = false }
        if let response = try? await APIClient.shared.request(Endpoint.listPlans) as PlansResponse {
            plans = response.plans
        }
    }

    private var fallbackPlans: [SubscriptionPlan] {
        [
            SubscriptionPlan(id: "pro_monthly", name: "Pro Monthly", pricePaise: 29900,
                             billingCycle: "monthly", savingPct: nil, features: nil),
            SubscriptionPlan(id: "pro_annual", name: "Pro Annual", pricePaise: 179900,
                             billingCycle: "annual", savingPct: 50, features: nil),
            SubscriptionPlan(id: "lifetime", name: "Lifetime Access", pricePaise: 349900,
                             billingCycle: "lifetime", savingPct: nil, features: nil)
        ]
    }
}

// MARK: - Pricing Card

struct PricingCard: View {
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
                                .font(.lexisCaptionM)
                                .foregroundColor(.moonPearl)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.jadeGreen.opacity(0.35))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.jadeGreen.opacity(0.5), lineWidth: 1))
                        }
                    }

                    Text(plan.isLifetime ? "Pay once, own forever" : "Billed \(plan.billingCycle ?? "")")
                        .font(.lexisCaption)
                        .foregroundColor(.textTertiary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(plan.priceDisplay)
                        .font(.lexisH2)
                        .foregroundColor(isSelected ? .white : .moonPearl)
                    if !plan.isLifetime {
                        Text(plan.cycleDisplay)
                            .font(.lexisCaption)
                            .foregroundColor(.textTertiary)
                    }
                }
            }
            .padding(Spacing.md)
            .background(
                isSelected
                ? AnyView(LinearGradient.hero.opacity(0.18))
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
            .shadow(color: isSelected ? Color.cobaltBlue.opacity(0.15) : .clear, radius: 12, y: 6)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Slide in modifier
fileprivate extension View {
    func slideInFromBottom(delay: Double, visible: Bool) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay), value: visible)
    }
}

// MARK: - Google Email Sheet (dev mode)

struct GoogleEmailSheet: View {
    @State private var email = ""
    let onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.inkBlack.opacity(0.9).ignoresSafeArea()
                VStack(spacing: Spacing.xl) {
                    Text("Enter your Google email to continue")
                        .font(.lexisBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)

                    TextField("", text: $email, prompt: Text("you@gmail.com").foregroundColor(.textTertiary))
                        .foregroundColor(.moonPearl)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding(Spacing.lg)
                        .background(Color.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(Color.glassBorderActive, lineWidth: 1)
                        )
                        .padding(.horizontal, Spacing.xl)

                    Button("Continue with Google") {
                        guard !email.isEmpty else { return }
                        onSubmit(email)
                    }
                    .primaryStyle()
                    .padding(.horizontal, Spacing.xl)
                }
            }
            .navigationTitle("Google Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Email Auth Sheet

struct EmailAuthSheet: View {
    @Bindable var vm: AuthViewModel
    let onSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.inkBlack.opacity(0.9).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Toggle
                        Picker("", selection: $vm.isRegisterMode) {
                            Text("Sign In").tag(false)
                            Text("Create Account").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Spacing.xl)

                        VStack(spacing: Spacing.md) {
                            if vm.isRegisterMode {
                                LexisTextField(placeholder: "Your name", text: $vm.displayName)
                            }
                            LexisTextField(placeholder: "Email", text: $vm.email, keyboard: .emailAddress)
                            LexisTextField(placeholder: "Password", text: $vm.password, isSecure: true)
                        }
                        .padding(.horizontal, Spacing.xl)

                        if let msg = vm.errorMessage {
                            Text(msg)
                                .font(.lexisCaption)
                                .foregroundColor(.coralRed)
                                .padding(.horizontal, Spacing.xl)
                        }

                        Button(vm.isRegisterMode ? "Create Account" : "Sign In") {
                            Task {
                                await vm.submitEmailAuth()
                                if AuthSession.shared.isAuthenticated {
                                    dismiss()
                                    onSuccess()
                                }
                            }
                        }
                        .primaryStyle(isLoading: vm.isLoading)
                        .padding(.horizontal, Spacing.xl)
                    }
                    .padding(.top, Spacing.xl)
                    .padding(.bottom, 48)
                }
            }
            .navigationTitle(vm.isRegisterMode ? "Create Account" : "Welcome Back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Text Field

struct LexisTextField: View {
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.textTertiary))
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.textTertiary))
                    .keyboardType(keyboard)
                    .autocapitalization(.none)
            }
        }
        .foregroundColor(.moonPearl)
        .padding(Spacing.lg)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.md)
                .stroke(Color.glassBorderActive, lineWidth: 1)
        )
    }
}

// MARK: - Error Toast

struct ErrorToast: View {
    let message: String
    var onDismiss: (() -> Void)? = nil

    @State private var dismissTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.coralRed)
            Text(message)
                .font(.lexisBodySm)
                .foregroundColor(.moonPearl)
                .lineLimit(3)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(Color.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        .padding(.horizontal, Spacing.xl)
        .onTapGesture {
            dismissTask?.cancel()
            onDismiss?()
        }
        .onAppear {
            dismissTask?.cancel()
            guard onDismiss != nil else { return }
            dismissTask = Task {
                try? await Task.sleep(for: .seconds(4))
                await MainActor.run { onDismiss?() }
            }
        }
        .onDisappear { dismissTask?.cancel() }
    }
}
