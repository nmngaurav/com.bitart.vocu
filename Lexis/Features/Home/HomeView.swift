import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm = HomeViewModel()
    @State private var showSubscription = false
    @State private var showRecap = false
    @State private var cardsAppeared = false
    @State private var welcomeAnimationDone: Bool = UserDefaults.standard.bool(forKey: "hasShownHomeWelcome")

    private let todayKey = TodayWordActivityWriter.dayKey()
    @Query private var todayWords: [WordDayActivityRecord]

    init() {
        let key = TodayWordActivityWriter.dayKey()
        _todayWords = Query(
            filter: #Predicate<WordDayActivityRecord> { $0.dayKey == key },
            sort: \WordDayActivityRecord.lastUpdatedAt,
            order: .reverse
        )
    }

    var body: some View {
        ZStack {
            Color.inkBlack.ignoresSafeArea()

            if vm.isLoading && !vm.hasCompletedInitialHomeLoad {
                LoadingHomeView()
            } else if vm.errorMessage != nil, vm.resolvedStreak == nil {
                NetworkErrorView { Task { await vm.loadAll() } }
            } else if vm.isNewUser {
                // Full-screen premium hero until first words are tracked (no compact top-only card).
                NewUserWelcomeView(
                    skipLibraryFade: welcomeAnimationDone,
                    greetingName: vm.greetingName,
                    isGuest: AuthSession.shared.isAnonymous,
                    libraryWordHint: vm.heroLibraryWordCount,
                    onBegin: { vm.showReviewSession = true },
                    onLibraryIntroComplete: {
                        UserDefaults.standard.set(true, forKey: "hasShownHomeWelcome")
                        welcomeAnimationDone = true
                    }
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        headerView
                            .slideInFromTop(delay: 0.0, visible: cardsAppeared, reduceMotion: reduceMotion)

                        if vm.hasPausedSession {
                            ReviewCTACard(
                                phase: vm.reviewCTAPhase,
                                onBegin: { vm.showReviewSession = true },
                                hasPausedSession: true,
                                completedSessionToday: vm.completedSessionToday,
                                onRecap: { showRecap = true }
                            )
                            .slideInFromTop(delay: 0.07, visible: cardsAppeared, reduceMotion: reduceMotion)

                            TodayStatsCard(
                                hasProgress: vm.totalWordsSeen > 0,
                                wordsMasteredForRetentionGate: vm.wordsLearned,
                                wordsLearning: vm.wordsLearning,
                                retentionPct: vm.retentionPercent,
                                dueToday: vm.dueTodayCount
                            )
                            .slideInFromTop(delay: 0.14, visible: cardsAppeared, reduceMotion: reduceMotion)
                        } else if case .caughtUp = vm.reviewCTAPhase {
                            StreakProgressHeroCard(
                                streak: vm.resolvedStreak,
                                history: vm.streakHistory,
                                dueToday: vm.dueTodayCount,
                                wordsNew: vm.wordsNew,
                                wordsLearning: vm.wordsLearning,
                                wordsMastered: vm.wordsLearned,
                                retentionPct: vm.retentionPercent,
                                hasProgress: vm.totalWordsSeen > 0
                            )
                            .slideInFromTop(delay: 0.07, visible: cardsAppeared, reduceMotion: reduceMotion)

                            ReviewCTACard(
                                phase: .caughtUp,
                                onBegin: { vm.showReviewSession = true },
                                hasPausedSession: false,
                                completedSessionToday: vm.completedSessionToday,
                                onRecap: { showRecap = true }
                            )
                            .slideInFromTop(delay: 0.14, visible: cardsAppeared, reduceMotion: reduceMotion)
                        } else {
                            StreakHeaderView(streak: vm.resolvedStreak, history: vm.streakHistory)
                                .slideInFromTop(delay: 0.07, visible: cardsAppeared, reduceMotion: reduceMotion)

                            ReviewCTACard(
                                phase: vm.reviewCTAPhase,
                                onBegin: { vm.showReviewSession = true },
                                hasPausedSession: false,
                                completedSessionToday: vm.completedSessionToday,
                                onRecap: { showRecap = true }
                            )
                            .slideInFromTop(delay: 0.14, visible: cardsAppeared, reduceMotion: reduceMotion)

                            TodayStatsCard(
                                hasProgress: vm.totalWordsSeen > 0,
                                wordsMasteredForRetentionGate: vm.wordsLearned,
                                wordsLearning: vm.wordsLearning,
                                retentionPct: vm.retentionPercent,
                                dueToday: vm.dueTodayCount
                            )
                            .slideInFromTop(delay: 0.20, visible: cardsAppeared, reduceMotion: reduceMotion)
                        }

                        Spacer().frame(height: 90)
                    }
                    .padding(.top, Spacing.sm)
                }
                .refreshable { await vm.loadAll() }
            }
        }
        .task { await vm.loadAll() }
        .onAppear {
            if reduceMotion {
                cardsAppeared = true
            } else {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.88).delay(0.05)) {
                    cardsAppeared = true
                }
            }
        }
        .onChange(of: vm.isNewUser) { _, isNew in
            // User just finished their first session — reset so welcome screen doesn't re-appear
            if !isNew {
                UserDefaults.standard.set(true, forKey: "hasShownHomeWelcome")
                welcomeAnimationDone = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vocuShowRecap)) { _ in
            if vm.completedSessionToday || !todayWords.isEmpty {
                showRecap = true
            }
        }
        .fullScreenCover(isPresented: $vm.showReviewSession) {
            ReviewSessionView {
                vm.showReviewSession = false
                Task { await vm.loadAll() }
            }
        }
        .fullScreenCover(item: $vm.libraryBrowsePack) { pack in
            LibraryBrowseView(pack: pack) {
                vm.libraryBrowsePack = nil
                Task { await vm.loadAll() }
            }
        }
        .fullScreenCover(isPresented: $showSubscription) {
            SubscriptionView()
        }
        .fullScreenCover(isPresented: $showRecap) {
            SessionRecapView(dayKey: todayKey, onDismiss: { showRecap = false })
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.greeting)
                    .font(.lexisCaption)
                    .foregroundColor(.textSecondary)

                if AuthSession.shared.isAnonymous {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text("vocu")
                            .font(.lexisH1)
                            .foregroundColor(.moonPearl)
                        Text("Guest")
                            .font(.lexisCaptionM)
                            .foregroundColor(.amberGlow)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 3)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.amberGlow.opacity(0.35), lineWidth: 1))
                    }
                } else {
                    Text(vm.greetingName)
                        .font(.lexisH1)
                        .foregroundColor(.moonPearl)
                }
            }

            Spacer()

            // Crown / PRO button — opens subscription
            Button {
                showSubscription = true
            } label: {
                if AuthSession.shared.isProUser {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(LinearGradient.hero)
                        Text("PRO")
                            .font(.lexisCaptionM)
                            .foregroundColor(.amberGlow)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.amberGlow.opacity(0.4), lineWidth: 1))
                } else {
                    Image(systemName: "crown")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.amberGlow.opacity(0.85))
                        .frame(width: 36, height: 36)
                        .background(Color.amberGlow.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.amberGlow.opacity(0.22), lineWidth: 1))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.sm)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [Color.cobaltBlue.opacity(0.2), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - New User Welcome Screen

private struct NewUserWelcomeView: View {
    /// When true, library block is shown immediately (user has already seen the fade once).
    var skipLibraryFade: Bool = false
    let greetingName: String
    let isGuest: Bool
    let libraryWordHint: Int
    let onBegin: () -> Void
    let onLibraryIntroComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var libraryOpacity: Double = 0
    @State private var libraryOffsetY: CGFloat = 20
    @State private var ambientPulse: CGFloat = 1.0
    @State private var didReportLibraryIntro = false
    @State private var featuresRevealed = false

    var body: some View {
        ZStack {
            Color.inkBlack.ignoresSafeArea()
            RadialGradient(
                colors: [
                    Color.cobaltBlue.opacity(0.15),
                    Color.inkBlack.opacity(0.92),
                    Color.inkBlack
                ],
                center: .top,
                startRadius: 40,
                endRadius: 520
            )
            .ignoresSafeArea()
            ParticleFieldView(tintColor: .moonPearl)
                .ignoresSafeArea()
                .opacity(reduceMotion ? 0.12 : 0.22)

            GeometryReader { geo in
                let safeTop = max(geo.safeAreaInsets.top, 12)
                VStack(alignment: .leading, spacing: 0) {
                    welcomeHeader
                        .padding(.horizontal, Spacing.xl)
                        .padding(.top, safeTop + Spacing.sm)
                        .padding(.bottom, Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)

                    libraryColumn(geo: geo)
                        .opacity(libraryOpacity)
                        .offset(y: libraryOffsetY)

                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear(perform: runLibraryIntro)
        .onChange(of: libraryOpacity) { _, newVal in
            guard newVal >= 0.99, !reduceMotion, !featuresRevealed else { return }
            withAnimation(.spring(response: 0.52, dampingFraction: 0.86).delay(0.1)) {
                featuresRevealed = true
            }
        }
    }

    private var welcomeHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Welcome,")
                .font(.lexisCaption)
                .foregroundColor(.textSecondary)

            if isGuest {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text("vocu")
                        .font(.lexisH1)
                        .foregroundColor(.moonPearl)
                    Text("Guest")
                        .font(.lexisCaptionM)
                        .foregroundColor(.amberGlow)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.amberGlow.opacity(0.35), lineWidth: 1))
                }
            } else {
                Text(greetingName)
                    .font(.lexisH1)
                    .foregroundStyle(LinearGradient.hero)
            }
        }
    }

    private func libraryColumn(geo: GeometryProxy) -> some View {
        GlassCard(padding: Spacing.xl) {
            VStack(spacing: Spacing.xxl) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.hero.opacity(0.28))
                        .frame(width: 140, height: 140)
                        .blur(radius: 36)
                        .scaleEffect(ambientPulse)
                    ZStack {
                        Circle()
                            .fill(LinearGradient.hero)
                            .frame(width: 96, height: 96)
                            .shadow(color: .cobaltBlue.opacity(0.5), radius: 22, y: 10)
                        Text("v")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }

                VStack(spacing: Spacing.md) {
                    Text("Your library is ready")
                        .font(.lexisDisplay2)
                        .foregroundColor(.moonPearl)
                        .multilineTextAlignment(.center)

                    if libraryWordHint > 0 {
                        Text("\(libraryWordHint) words waiting for you")
                            .font(.lexisBody)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("We’ve curated the right words for you.\nLearn them in context with science-backed repetition.")
                            .font(.lexisBody)
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                }
                .padding(.horizontal, Spacing.sm)

                Button {
                    Haptics.impact(.medium)
                    onBegin()
                } label: {
                    Text("Begin your journey")
                }
                .primaryStyle()
                .frame(maxWidth: .infinity)

                HStack(spacing: Spacing.md) {
                    welcomeFeature(icon: "brain.head.profile", text: "Spaced repetition", index: 0)
                    welcomeFeature(icon: "flame.fill", text: "Daily streaks", index: 1)
                    welcomeFeature(icon: "books.vertical.fill", text: "Curated packs", index: 2)
                }
                .padding(.top, Spacing.xs)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, max(Spacing.md, geo.safeAreaInsets.bottom + 4))
        .frame(maxWidth: .infinity)
    }

    private func welcomeFeature(icon: String, text: String, index: Int) -> some View {
        WelcomeStat(icon: icon, text: text)
            .opacity(featuresRevealed ? 1 : 0)
            .offset(y: featuresRevealed ? 0 : 16)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.84)
                    .delay(Double(index) * 0.07),
                value: featuresRevealed
            )
    }

    private func startAmbientIfNeeded() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            ambientPulse = 1.06
        }
    }

    private func runLibraryIntro() {
        startAmbientIfNeeded()
        if skipLibraryFade || reduceMotion {
            libraryOpacity = 1
            libraryOffsetY = 0
            featuresRevealed = true
            reportLibraryIntroCompleteOnce()
            return
        }
        withAnimation(.easeOut(duration: 0.95)) {
            libraryOpacity = 1
            libraryOffsetY = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            reportLibraryIntroCompleteOnce()
        }
    }

    private func reportLibraryIntroCompleteOnce() {
        guard !didReportLibraryIntro else { return }
        didReportLibraryIntro = true
        onLibraryIntroComplete()
    }
}

private struct WelcomeStat: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.cobaltBlue)
            Text(text)
                .font(.lexisCaption)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Slide-in animation modifier

private extension View {
    func slideInFromTop(delay: Double, visible: Bool, reduceMotion: Bool) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .offset(y: (visible || reduceMotion) ? 0 : -14)
            .animation(
                reduceMotion ? .default : .spring(response: 0.52, dampingFraction: 0.85).delay(delay),
                value: visible
            )
    }
}

// MARK: - Loading Skeleton

struct LoadingHomeView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            ShimmerCard(height: 36).padding(.horizontal, Spacing.xl)
            ShimmerCard(height: 110).padding(.horizontal, Spacing.xl)
            ShimmerCard(height: 100).padding(.horizontal, Spacing.xl)
            ShimmerCard(height: 80).padding(.horizontal, Spacing.xl)
        }
        .padding(.top, Spacing.xxxl)
    }
}
