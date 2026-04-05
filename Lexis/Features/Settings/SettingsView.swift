import SwiftUI

struct SettingsView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(ThemeManager.self) private var themeManager
    @State private var vm = SettingsViewModel()
    @State private var showSubscription = false
    @State private var showNameEdit = false
    @State private var showNotificationSheet = false
    @FocusState private var nameFocused: Bool
    @Namespace private var themeAnimation

    var body: some View {
        ZStack {
            Color.inkBlack.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    settingsHeader

                    if AuthSession.shared.isAnonymous {
                        guestBanner
                    }

                    profileSection

                    subscriptionSection

                    themeSection

                    preferencesSection

                    dangerSection

                    footerSection

                    Spacer().frame(height: 90)
                }
                .padding(.top, Spacing.xxl)
            }
        }
        .onAppear { vm.clearError() }
        .task { await vm.load() }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $showNotificationSheet) {
            notificationTimeSheet
        }
        .overlay(alignment: .top) {
            if let msg = vm.errorMessage {
                ErrorToast(message: msg) {
                    vm.clearError()
                }
                .padding(.top, 60)
            }
        }
    }

    private func learnerStatRow(title: String, value: String, valueColor: Color) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lexisCaption)
                    .foregroundColor(.textTertiary)
                Text(value)
                    .font(.lexisH2)
                    .foregroundColor(valueColor)
            }
            Spacer()
        }
    }

    // MARK: - Header

    private var settingsHeader: some View {
        HStack {
            Text("Settings")
                .font(.lexisDisplay3)
                .foregroundColor(.moonPearl)
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Guest banner

    private var guestBanner: some View {
        Button { coordinator.openAuthFlow() } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 22))
                    .foregroundColor(.amberGlow)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Save your progress")
                        .font(.lexisBodyM)
                        .foregroundColor(.moonPearl)
                    Text("Create a free account to sync streaks across devices.")
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
            .padding(Spacing.lg)
            .background(
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    LinearGradient(
                        colors: [Color.amberGlow.opacity(0.2), Color.amberGlow.opacity(0.05)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.amberGlow.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Profile

    private var profileSection: some View {
        GlassCard(padding: Spacing.lg) {
            HStack(spacing: Spacing.lg) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.hero)
                        .frame(width: 52, height: 52)
                    Text(String((vm.user?.displayNameOrFallback.prefix(1) ?? "v").uppercased()))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.user?.displayNameOrFallback ?? "Learner")
                        .font(.lexisH3)
                        .foregroundColor(.moonPearl)
                    Text(vm.displayEmail)
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Button {
                    vm.editingName = vm.user?.displayName ?? ""
                    showNameEdit = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Color.glassBorder)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .sheet(isPresented: $showNameEdit) { editNameSheet }
    }

    private var editNameSheet: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                VStack(spacing: Spacing.xl) {
                    LexisTextField(placeholder: "Display name", text: $vm.editingName)
                        .padding(.horizontal, Spacing.xl)
                        .focused($nameFocused)

                    Button("Save") {
                        Task {
                            await vm.saveDisplayName()
                            showNameEdit = false
                        }
                    }
                    .primaryStyle(isLoading: vm.isSaving)
                    .padding(.horizontal, Spacing.xl)
                }
                .padding(.top, Spacing.xl)
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showNameEdit = false }.foregroundColor(.textSecondary)
                }
            }
            .onAppear { nameFocused = true }
        }
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Subscription

    private var subscriptionSection: some View {
        GlassCard(padding: Spacing.lg) {
            Button { showSubscription = true } label: {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundColor(vm.subscriptionColor)
                    Text("Subscription")
                        .font(.lexisBodyM)
                        .foregroundColor(.moonPearl)
                    Spacer()
                    Text(vm.subscriptionLabel)
                        .font(.lexisCaptionM)
                        .foregroundColor(vm.subscriptionColor)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 4)
                        .background(vm.subscriptionColor.opacity(0.1))
                        .clipShape(Capsule())
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Theme picker

    private var themeSection: some View {
        GlassCard(padding: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Appearance")
                    .font(.lexisCaptionM)
                    .foregroundColor(.textTertiary)
                    .tracking(1)

                HStack(spacing: Spacing.sm) {
                    ForEach(AppearanceMode.allCases) { mode in
                        let isSelected = themeManager.appearance == mode
                        Button {
                            Haptics.impact(.light)
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                themeManager.appearance = mode
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(isSelected ? .cobaltBlue : .textTertiary)
                                Text(mode.displayName)
                                    .font(.lexisCaption)
                                    .foregroundColor(isSelected ? .moonPearl : .textTertiary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                ZStack {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                            .fill(Color.cobaltBlue.opacity(0.2))
                                            .matchedGeometryEffect(id: "themeSelection", in: themeAnimation)
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                                    .stroke(
                                        isSelected ? Color.cobaltBlue.opacity(0.6) : Color.glassBorder,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Preferences (notification reminder + version, no daily goal)

    private var preferencesSection: some View {
        GlassCard(padding: Spacing.lg) {
            VStack(spacing: Spacing.lg) {
                Text("Preferences")
                    .font(.lexisCaptionM)
                    .foregroundColor(.textTertiary)
                    .tracking(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button { showNotificationSheet = true } label: {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundColor(.cobaltBlue)
                        Text("Daily reminder")
                            .font(.lexisBodyM)
                            .foregroundColor(.moonPearl)
                        Spacer()
                        Text(SettingsViewModel.notificationTimeString(from: vm.editingNotificationTime))
                            .font(.lexisCaptionM)
                            .foregroundColor(.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundColor(.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                Divider().background(Color.glassBorder)

                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.textSecondary)
                    Text("Version")
                        .font(.lexisBodyM)
                        .foregroundColor(.moonPearl)
                    Spacer()
                    Text(vm.appVersionLabel)
                        .font(.lexisCaption)
                        .foregroundColor(.textTertiary)
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
    }

    private var notificationTimeSheet: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                VStack(spacing: Spacing.xl) {
                    DatePicker(
                        "Daily reminder",
                        selection: $vm.editingNotificationTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .colorScheme(themeManager.effectiveColorScheme)

                    Button("Save") {
                        Task {
                            await vm.saveNotificationTime(vm.editingNotificationTime)
                            showNotificationSheet = false
                        }
                    }
                    .primaryStyle(isLoading: vm.isSaving)
                }
                .padding(Spacing.xl)
            }
            .navigationTitle("Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showNotificationSheet = false }
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Danger

    private var dangerSection: some View {
        GlassCard(padding: Spacing.lg) {
            Button {
                Haptics.impact(.medium)
                Task { await vm.signOut(coordinator: coordinator) }
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.coralRed)
                    Text("Sign Out")
                        .font(.lexisBodyM)
                        .foregroundColor(.coralRed)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.xl) {
                if let terms = URL(string: "https://example.com/terms") {
                    Link("Terms", destination: terms)
                        .font(.lexisCaption)
                        .foregroundColor(.cobaltBlue)
                }
                if let privacy = URL(string: "https://example.com/privacy") {
                    Link("Privacy", destination: privacy)
                        .font(.lexisCaption)
                        .foregroundColor(.cobaltBlue)
                }
                Button("Restore") { showSubscription = true }
                    .font(.lexisCaption)
                    .foregroundColor(.textSecondary)
            }
            Text("vocu · vocabulary that sticks")
                .font(.lexisCaption)
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.sm)
    }
}
