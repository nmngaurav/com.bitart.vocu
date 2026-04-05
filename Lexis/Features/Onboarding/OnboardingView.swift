import SwiftUI

// MARK: - Main Onboarding Container

struct OnboardingView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm = OnboardingViewModel()
    @State private var showSkip = false

    var body: some View {
        ZStack {
            Color.inkBlack.ignoresSafeArea()

            ParticleFieldView(tintColor: dynamicColor(for: vm.currentPage))
                .ignoresSafeArea()
                .opacity(0.28)

            VStack(spacing: 0) {
                // Persistent Top Skip Button
                topBar
                    .padding(.horizontal, Spacing.xl)

                TabView(selection: $vm.currentPage) {
                    OnboardingIntroPage(isActive: vm.currentPage == 0)
                        .tag(0)
                    
                    OnboardingDemoPage(isActive: vm.currentPage == 1)
                        .tag(1)
                    
                    OnboardingBentoSection(isActive: true)
                        .tag(2)
                    
                    OnboardingGetStartedPage(isActive: vm.currentPage == 3)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Persistent Bottom Dock
                VStack(spacing: Spacing.lg) {
                    pageDots
                    ctaButtons
                }
                .padding(.bottom, 24)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { showSkip = true }
            }
        }
    }

    private func dynamicColor(for page: Int) -> Color {
        switch page {
        case 0: return .white
        case 1: return .cobaltBlue
        case 2: return .jadeGreen
        case 3: return .amberGlow
        default: return .white
        }
    }

    // MARK: - Top Bar (Skip)

    private var topBar: some View {
        HStack {
            Spacer()
            if showSkip && !vm.isLastPage {
                Button("Skip") {
                    Haptics.impact(.light)
                    coordinator.completeOnboarding()
                }
                .ghostStyle(color: .textSecondary)
                .transition(.opacity)
            }
        }
        .frame(height: 48)
        .animation(.easeOut(duration: 0.28), value: showSkip)
    }

    // MARK: - Page Dots

    private var pageDots: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<vm.totalPages, id: \.self) { i in
                Capsule()
                    .fill(
                        i == vm.currentPage
                            ? AnyShapeStyle(LinearGradient.hero)
                            : AnyShapeStyle(Color.textTertiary.opacity(0.45))
                    )
                    .frame(width: i == vm.currentPage ? 22 : 6, height: 6)
                    .animation(
                        reduceMotion
                            ? .default
                            : .spring(response: 0.38, dampingFraction: 0.72),
                        value: vm.currentPage
                    )
            }
        }
    }

    // MARK: - CTA Buttons

    private var ctaButtons: some View {
        ZStack {
            if vm.isLastPage {
                Button {
                    Haptics.impact(.medium)
                    coordinator.completeOnboarding()
                } label: {
                    Text("Start Learning")
                }
                .primaryStyle()
                .padding(.horizontal, Spacing.xl)
                .shadow(color: Color.cobaltBlue.opacity(0.48), radius: 22, y: 0)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
        .frame(height: 56)
        .animation(
            reduceMotion
                ? .default
                : .spring(response: 0.36, dampingFraction: 0.84),
            value: vm.isLastPage
        )
    }
}

// MARK: - Screen 0: Intro (Hook & Solution)

struct OnboardingIntroPage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var logoScale: CGFloat = 0.82
    @State private var logoOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var textOpacity: Double = 0
    @State private var badgesOpacity: Double = 0
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            AnimatedEbbinghausCurve(isActive: isActive)
                .frame(height: 180)
                .padding(.horizontal, Spacing.md)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

            Spacer().frame(height: Spacing.xxl)

            VStack(spacing: Spacing.sm) {
                Text("80% of new words fade\nwithin 24 hours")
                    .font(.lexisDisplay2)
                    .foregroundColor(.moonPearl)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Spacing.xl)

                Text("vocu fixes this with spaced repetition.")
                    .font(.lexisH1)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }
            .offset(y: textOffset)
            .opacity(textOpacity)

            Spacer().frame(height: Spacing.xxl)

            HStack(spacing: Spacing.md) {
                IntroBadge(text: "Science-backed", icon: "brain.head.profile")
                IntroBadge(text: "5 min / day", icon: "clock.fill")
            }
            .opacity(badgesOpacity)

            Spacer()
        }
        .onAppear { if isActive { animateIn() } }
        .onChange(of: isActive) { _, active in if active { animateIn() } }
    }

    private func animateIn() {
        if reduceMotion {
            logoScale = 1; logoOpacity = 1
            textOffset = 0; textOpacity = 1
            badgesOpacity = 1
            glowPulse = true
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.02)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.12)) {
            textOffset = 0
            textOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.24)) {
            badgesOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { glowPulse = true }
        }
    }
}

struct IntroBadge: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.cobaltBlue)
            Text(text)
                .font(.lexisCaptionM)
                .foregroundColor(.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.glassBorder.opacity(0.6))
        .overlay(Capsule().stroke(Color.glassBorderActive, lineWidth: 1))
        .clipShape(Capsule())
    }
}

// MARK: - Screen 2: Interactive Demo

private enum DemoPhase {
    case front, back, rated
}

struct OnboardingDemoPage: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var headerOpacity: Double = 0
    @State private var headerOffset: CGFloat = 12
    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.88

    @State private var showBack = false
    @State private var pulseOuter = false
    @State private var pulseInner = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("See how it works")
                    .font(.lexisH1)
                    .foregroundColor(.moonPearl)

                Text(showBack ? "Here’s the meaning. Tap to flip back." : "Tap the card to reveal its meaning")
                    .font(.lexisBodySm)
                    .foregroundColor(.textSecondary)
                    .animation(.easeOut(duration: 0.25), value: showBack)
            }
            .opacity(headerOpacity)
            .offset(y: headerOffset)

            Spacer().frame(height: Spacing.xl)

            // Premium Demo Card 1:1 Mirror
            ZStack {
                OnboardingDemoCard(
                    showBack: showBack,
                    onToggleContext: { toggleCard() }
                )
                .scaleEffect(cardScale)
                .opacity(cardOpacity)

                if !showBack && !reduceMotion {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            .frame(width: 70, height: 70)
                            .scaleEffect(pulseOuter ? 1.6 : 1.0)
                            .opacity(pulseOuter ? 0 : 1)
                        
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)
                            .scaleEffect(pulseInner ? 1.2 : 1.0)
                            .opacity(pulseInner ? 0 : 1)
                    }
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false)) {
                            pulseOuter = true
                        }
                        withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false).delay(0.2)) {
                            pulseInner = true
                        }
                    }
                }
            }

            Spacer()
        }
        .onAppear { if isActive { animateIn() } }
        .onChange(of: isActive) { _, active in
            if active {
                animateIn()
            } else {
                resetDemo()
            }
        }
    }

    private func toggleCard() {
        Haptics.impact(.light)
        showBack.toggle()
    }

    private func animateIn() {
        if reduceMotion {
            headerOpacity = 1; headerOffset = 0; cardOpacity = 1; cardScale = 1.0
            return
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.04)) {
            headerOpacity = 1
            headerOffset = 0
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.76).delay(0.1)) {
            cardOpacity = 1
            cardScale = 1.0
        }
    }

    private func resetDemo() {
        showBack = false
        headerOpacity = 0
        headerOffset = 12
        cardOpacity = 0
        cardScale = 0.88
    }
}

// MARK: - Screen 3: Premium Bento Showcase

struct OnboardingBentoSection: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var gridScale: CGFloat = 0.94
    @State private var gridOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 16

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            VStack(spacing: Spacing.sm) {
                Text("Everything you need.")
                    .font(.lexisDisplay2)
                    .foregroundColor(.moonPearl)
                    .multilineTextAlignment(.center)
                
                Text("Beautifully simple. Powerfully effective.")
                    .font(.lexisBodySm)
                    .foregroundColor(.textSecondary)
            }
            .opacity(titleOpacity)
            .offset(y: titleOffset)

            // The Bento Grid
            VStack(spacing: Spacing.md) {
                // Top Half: Fire Streak Hero
                BentoStreakHero()
                    .frame(height: 180)

                // Bottom Half: Split Widgets
                HStack(spacing: Spacing.md) {
                    BentoMiniDeck()
                    BentoXPBar()
                }
                .frame(height: 180)
            }
            .padding(.horizontal, Spacing.xl)
            .opacity(gridOpacity)
            .scaleEffect(gridScale)

            Spacer()
        }
        .onAppear { if isActive { animateIn() } }
    }

    private func animateIn() {
        if reduceMotion {
            titleOpacity = 1; titleOffset = 0; gridOpacity = 1; gridScale = 1
            return
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.02)) {
            titleOpacity = 1; titleOffset = 0
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.74).delay(0.12)) {
            gridOpacity = 1; gridScale = 1.0
        }
    }
}

// MARK: - Bento UI Widgets

struct BentoStreakHero: View {
    var body: some View {
        ZStack {
            Color.amberGlow.opacity(0.12)
            RadialGradient(colors: [Color.amberGlow.opacity(0.15), .clear], center: .bottom, startRadius: 20, endRadius: 180)

            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Daily Rhythm")
                        .font(.lexisCaptionM)
                        .foregroundColor(.amberGlow)
                    Text("3 Day")
                        .font(.system(size: 32, weight: .black))
                        .foregroundColor(.moonPearl)
                    Text("Streak Fire")
                        .font(.lexisBodySm)
                        .foregroundColor(.textSecondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(Color.amberGlow.opacity(0.2)).frame(width: 80, height: 80).blur(radius: 20)
                    Text("🔥")
                        .font(.system(size: 60))
                        .shadow(color: Color.amberGlow.opacity(0.6), radius: 10, y: 10)
                }
            }
            .padding(.horizontal, Spacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.glassBorderActive, lineWidth: 1))
    }
}

struct BentoMiniDeck: View {
    var body: some View {
        ZStack {
            Color.cobaltBlue.opacity(0.12)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.cobaltBlue)
                    Spacer()
                }
                Spacer()
                Text("Smart\nQueue")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.moonPearl)
                Text("Spaced rep")
                    .font(.lexisCaption)
                    .foregroundColor(.textTertiary)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.glassBorderActive, lineWidth: 1))
    }
}

struct BentoXPBar: View {
    var body: some View {
        ZStack {
            Color.jadeGreen.opacity(0.12)
            VStack(alignment: .leading, spacing: 4) {
                 HStack {
                    Image(systemName: "cellularbars")
                        .font(.system(size: 20))
                        .foregroundColor(.jadeGreen)
                    Spacer()
                }
                Spacer()
                Text("Track\nMastery")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.moonPearl)
                Text("+40 XP")
                    .font(.lexisCaption)
                    .foregroundColor(.jadeGreen)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.glassBorderActive, lineWidth: 1))
    }
}

// MARK: - Screen 4: Get Started

struct OnboardingGetStartedPage: View {
    let isActive: Bool
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var orbOpacity: Double = 0
    @State private var orbScale: CGFloat = 0.8
    @State private var textOpacity: Double = 0
    @State private var textOffset: CGFloat = 20
    @State private var statsOpacity: Double = 0
    @State private var statsOffset: CGFloat = 24
    @State private var glowPulse = false

    private let stats: [(value: String, label: String)] = [
        ("10K+", "words"),
        ("50+", "packs"),
        ("Free", "to start"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient.hero)
                    .frame(width: 220, height: 220)
                    .blur(radius: glowPulse ? 78 : 52)
                    .opacity(0.20)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                        value: glowPulse
                    )

                ZStack {
                    Circle()
                        .fill(LinearGradient.hero)
                        .frame(width: 88, height: 88)
                        .shadow(color: .cobaltBlue.opacity(0.48), radius: 24, y: 10)
                    Text("🚀")
                        .font(.system(size: 38))
                }
            }
            .scaleEffect(orbScale)
            .opacity(orbOpacity)

            Spacer().frame(height: Spacing.xxl)

            VStack(spacing: Spacing.md) {
                Text("You're all set to\nstart learning")
                    .font(.lexisDisplay3)
                    .foregroundColor(.moonPearl)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, Spacing.xl)

                Text("Your words, forever. Build streaks\nand track your mastery.")
                    .font(.lexisBodySm)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, Spacing.xl)
            }
            .opacity(textOpacity)
            .offset(y: textOffset)

            Spacer().frame(height: Spacing.xxl)

            HStack(spacing: Spacing.xxl) {
                ForEach(stats, id: \.value) { stat in
                    VStack(spacing: 3) {
                        Text(stat.value)
                            .font(.lexisH1)
                            .foregroundColor(.cobaltBlue)
                        Text(stat.label)
                            .font(.lexisCaption)
                            .foregroundColor(.textSecondary)
                    }
                }
            }
            .opacity(statsOpacity)
            .offset(y: statsOffset)

            Spacer().frame(height: Spacing.xxl)

            Spacer().frame(height: 80) // Push content up to avoid bottom dock

            Spacer()
        }
        .onAppear { if isActive { animateIn() } }
        .onChange(of: isActive) { _, active in if active { animateIn() } }
    }

    private func animateIn() {
        if reduceMotion {
            orbOpacity = 1; orbScale = 1
            textOpacity = 1; textOffset = 0
            statsOpacity = 1; glowPulse = true
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.02)) {
            orbOpacity = 1
            orbScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.12)) {
            textOpacity = 1
            textOffset = 0
        }
        withAnimation(.easeOut(duration: 0.3).delay(0.24)) {
            statsOpacity = 1
            statsOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { glowPulse = true }
        }
    }
}

// MARK: - Particle Field Canvas

struct ParticleFieldView: View {
    let tintColor: Color
    @State private var particles: [Particle] = ParticleFieldView.makeParticles()

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var size: CGFloat
        var opacity: Double
        var speed: Double
        var drift: Double
    }

    static func makeParticles() -> [Particle] {
        (0..<52).map { _ in
            Particle(
                x: CGFloat.random(in: 0...1),
                y: CGFloat.random(in: 0...1),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.08...0.35),
                speed: Double.random(in: 0.0002...0.0008),
                drift: Double.random(in: -0.0003...0.0003)
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let x = (particle.x + particle.drift * t).truncatingRemainder(dividingBy: 1) * size.width
                    let y = (1.0 - (particle.y + particle.speed * t).truncatingRemainder(dividingBy: 1)) * size.height
                    let rect = CGRect(x: x, y: y, width: particle.size, height: particle.size)
                    context.opacity = particle.opacity * (0.5 + 0.5 * sin(t * 1.1 + particle.x * 10))
                    context.fill(Path(ellipseIn: rect), with: .color(tintColor))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Animated Forgetting Curve

struct AnimatedEbbinghausCurve: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var decayProgress: CGFloat = 0
    @State private var retentionProgress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            ZStack(alignment: .topLeading) {
                // Background grid lines to ground the chart
                VStack(spacing: 0) {
                    Divider().background(Color.glassBorder.opacity(0.5))
                    Spacer()
                    Divider().background(Color.glassBorder.opacity(0.5))
                    Spacer()
                    Divider().background(Color.glassBorder.opacity(0.5))
                }
                
                // Decay Curve (Without vocu)
                decayCurve(w: w, h: h)
                    .trim(from: 0, to: decayProgress)
                    .stroke(Color.coralRed, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .shadow(color: Color.coralRed.opacity(0.4), radius: 6, x: 0, y: 3)

                // Decay Glowing Playhead
                decayCurve(w: w, h: h)
                    .trim(from: max(0, decayProgress - 0.05), to: decayProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .shadow(color: Color.white.opacity(decayProgress > 0 && decayProgress < 1 ? 0.9 : 0), radius: 8, x: 0, y: 0)
                
                // Retention Curve (With vocu spaced repetition)
                retentionCurve(w: w, h: h)
                    .trim(from: 0, to: retentionProgress)
                    .stroke(Color.cobaltBlue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .shadow(color: Color.cobaltBlue.opacity(0.6), radius: 8, x: 0, y: 4)

                // Retention Glowing Playhead
                retentionCurve(w: w, h: h)
                    .trim(from: max(0, retentionProgress - 0.04), to: retentionProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .shadow(color: Color.white.opacity(retentionProgress > 0 && retentionProgress < 1 ? 0.9 : 0), radius: 8, x: 0, y: 0)
            }
            .overlay(
                Text("Memory\nRetention")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.textTertiary)
                    .rotationEffect(.degrees(-90))
                    .offset(x: -28, y: 0),
                alignment: .leading
            )
            .overlay(
                Text("Time")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.textTertiary)
                    .offset(x: 0, y: 20),
                alignment: .bottom
            )
        }
        .padding(.leading, 24)
        .padding(.bottom, 20)
        .onAppear { if isActive { animateIn() } }
        .onChange(of: isActive) { _, active in
            if active { animateIn() } else { reset() }
        }
    }

    private func animateIn() {
        if reduceMotion {
            decayProgress = 1; retentionProgress = 1; return
        }
        withAnimation(.easeOut(duration: 1.2).delay(0.1)) {
            decayProgress = 1.0
        }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.72).delay(0.6)) {
            retentionProgress = 1.0
        }
    }

    private func reset() {
        decayProgress = 0
        retentionProgress = 0
    }

    private func decayCurve(w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.85),
            control1: CGPoint(x: w * 0.15, y: h * 0.7),
            control2: CGPoint(x: w * 0.4, y: h * 0.8)
        )
        return path
    }

    private func retentionCurve(w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(
            to: CGPoint(x: w * 0.33, y: h * 0.1),
            control1: CGPoint(x: w * 0.1, y: h * 0.3),
            control2: CGPoint(x: w * 0.25, y: h * 0.15)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.66, y: h * 0.05),
            control1: CGPoint(x: w * 0.45, y: h * 0.2),
            control2: CGPoint(x: w * 0.55, y: h * 0.08)
        )
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.02),
            control1: CGPoint(x: w * 0.75, y: h * 0.1),
            control2: CGPoint(x: w * 0.85, y: h * 0.04)
        )
        return path
    }
}

// MARK: - Demo Card Wrapper

struct OnboardingDemoCard: View {
    let showBack: Bool
    let onToggleContext: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Backend-matched Jocular Demo Card
    private let demoCard = ReviewQueueCard(
        wordId: 8,
        cardType: "new",
        word: CardWordDetail(
            term: "Jocular",
            phonetic: "/ˈdʒɒk.jʊ.lər/",
            partOfSpeech: "adjective",
            definition: "Fond of or characterized by joking; humorous and playful.",
            audioUrl: nil, // no audio needed in demo
            primaryImageUrl: "jocular", // Loads via asset catalog
            example: "His jocular comments lightened the mood of the meeting."
        ),
        progress: CardProgress(repetitionCount: 0, memoryStrength: 0)
    )

    @State private var parallaxOffset = false
    @State private var pulseRing = false

    var body: some View {
        GeometryReader { geo in
            let viewport = geo.size
            let maxW = min(viewport.width, 380)
            let maxH = min(viewport.height, 540)
            
            ZStack(alignment: .bottom) {
                RevealableCardView(
                    card: demoCard,
                    isRevealed: showBack,
                    viewport: viewport,
                    onToggleReveal: onToggleContext
                )
                .id(showBack) // forces refresh or flip if needed
                
                // Pulsing Hint Overlay
                if !showBack {
                    Circle()
                        .stroke(Color.white.opacity(pulseRing ? 0 : 0.6), lineWidth: pulseRing ? 45 : 1)
                        .frame(width: 44, height: 44)
                        .opacity(pulseRing ? 0 : 1)
                        .padding(.bottom, 22)
                        .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: Color.black.opacity(0.26), radius: 22, x: 0, y: 10)
            .frame(width: maxW, height: maxH)
            .position(x: viewport.width / 2, y: viewport.height / 2)
        }
        .rotation3DEffect(
            .degrees(parallaxOffset ? 3 : -3),
            axis: (x: 1, y: 0.6, z: 0),
            perspective: 0.8
        )
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                    parallaxOffset = true
                }
                withAnimation(.easeOut(duration: 2.0).repeatForever(autoreverses: false).delay(1.0)) {
                    pulseRing = true
                }
            }
        }
    }
}
