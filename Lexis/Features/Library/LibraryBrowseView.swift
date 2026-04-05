import SwiftUI
import SwiftData

struct LibraryBrowseView: View {
    let pack: PackSummaryResponse
    let onDismiss: () -> Void

    @State private var vm = LibraryBrowseViewModel()
    @State private var pageIndex: Int = 0
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.deepNavy, Color.inkBlack],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if vm.isLoading && vm.words.isEmpty {
                VStack(spacing: Spacing.lg) {
                    ProgressView()
                        .tint(.cobaltBlue)
                        .scaleEffect(1.2)
                    Text("Loading \(pack.title)…")
                        .font(.lexisBody)
                        .foregroundColor(.textSecondary)
                }
            } else if let err = vm.errorMessage, vm.words.isEmpty {
                VStack(spacing: Spacing.xl) {
                    Text("⚠️")
                        .font(.system(size: 40))
                    Text(err)
                        .font(.lexisBody)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xxxl)
                    Button("Try again") {
                        Task { await vm.load(packId: pack.id) }
                    }
                    .primaryStyle()
                    .frame(width: 180)
                }
            } else if vm.words.isEmpty {
                EmptyStateView(
                    icon: "📖",
                    title: "No words yet",
                    subtitle: "This pack doesn’t have browseable words right now."
                )
                .padding(.horizontal, Spacing.xl)
            } else {
                GeometryReader { geo in
                    TabView(selection: $pageIndex) {
                        ForEach(Array(vm.words.enumerated()), id: \.element.id) { idx, word in
                            LibraryFlipCard(
                                word: word,
                                packTitle: pack.title,
                                onBrowseCommitted: {
                                    TodayWordActivityWriter.recordLibraryBrowse(
                                        modelContext: modelContext,
                                        wordId: word.id,
                                        term: word.term,
                                        imageUrl: word.primaryImageUrl
                                    )
                                    try? modelContext.save()
                                }
                            )
                            .padding(.horizontal, Spacing.lg)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .tag(idx)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }
            }
        }
        .safeAreaInset(edge: .top) {
            HStack {
                Button {
                    Haptics.impact(.light)
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.textSecondary)
                        .frame(width: 40, height: 40)
                        .background(Color.glassBorder)
                        .clipShape(Circle())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(pack.title)
                        .font(.lexisCaptionM)
                        .foregroundColor(.moonPearl)
                        .lineLimit(1)
                    if !vm.words.isEmpty {
                        Text("\(pageIndex + 1) / \(vm.words.count)")
                            .font(.lexisCaption)
                            .foregroundColor(.textTertiary)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(.ultraThinMaterial)
        }
        .task {
            await vm.load(packId: pack.id)
        }
    }
}

// MARK: - Flip card

private struct LibraryFlipCard: View {
    let word: PackWordProgressResponse
    let packTitle: String
    let onBrowseCommitted: () -> Void

    @State private var flipped = false
    @State private var flipRotation: Double = 0
    @State private var didRecordBrowse = false

    var body: some View {
        ZStack {
            frontFace
                .rotation3DEffect(.degrees(flipRotation), axis: (0, 1, 0), perspective: 0.5)
                .opacity(flipRotation < 90 ? 1 : 0)

            backFace
                .rotation3DEffect(.degrees(flipRotation + 180), axis: (0, 1, 0), perspective: 0.5)
                .opacity(flipRotation >= 90 ? 1 : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 28, y: 12)
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.impact(.light)
            withAnimation(.spring(response: 0.52, dampingFraction: 0.86)) {
                flipped.toggle()
                flipRotation = flipped ? 180 : 0
                if flipped && !didRecordBrowse {
                    didRecordBrowse = true
                    onBrowseCommitted()
                }
            }
        }
    }

    // MARK: Front Face — image only

    private var frontFace: some View {
        ZStack {
            if let urlStr = word.primaryImageUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        gradientPlaceholder
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            } else {
                gradientPlaceholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.deepNavy)
    }

    private var gradientPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.navyBlue.opacity(0.55), Color.cobaltBlue.opacity(0.32)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Text(String(word.term.prefix(1).uppercased()))
                .font(.system(size: 112, weight: .black))
                .foregroundColor(.white.opacity(0.07))
        }
    }

    // MARK: Back Face — info

    private var backFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Flip-back affordance
            HStack {
                Spacer()
                Image(systemName: "chevron.compact.up")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.textTertiary.opacity(0.7))
                Spacer()
            }
            .frame(height: 36)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Term row
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                            Rectangle()
                                .fill(LinearGradient.hero)
                                .frame(width: 3, height: 24)
                                .clipShape(Capsule())
                            Text(word.term)
                                .font(.lexisDisplay3)
                                .foregroundColor(.moonPearl)
                                .minimumScaleFactor(0.78)
                                .lineLimit(2)
                            if let pos = word.partOfSpeech, !pos.isEmpty {
                                Text(pos)
                                    .font(.lexisCaption)
                                    .foregroundColor(.textSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.glassBorder)
                                    .clipShape(Capsule())
                            }
                        }
                        if let ph = word.phonetic, !ph.isEmpty {
                            Text(ph)
                                .font(.lexisMono)
                                .foregroundColor(.textSecondary)
                                .padding(.leading, 11)
                        }
                        if let audio = word.audioUrl, !audio.isEmpty {
                            AudioChip(audioURLString: audio, fallbackWord: word.term)
                                .padding(.leading, 11)
                        }
                    }

                    Divider().background(Color.glassBorder.opacity(0.85))

                    // Definition
                    if let def = word.definition, !def.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("DEFINITION")
                                .font(.lexisMonoSm)
                                .foregroundColor(.textTertiary)
                                .tracking(1.2)
                            Text(def)
                                .font(.lexisBody)
                                .foregroundColor(.moonPearl)
                                .lineSpacing(6)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Example
                    if let ex = word.example, !ex.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("EXAMPLE")
                                .font(.lexisMonoSm)
                                .foregroundColor(.textTertiary)
                                .tracking(1.2)
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Rectangle()
                                    .fill(LinearGradient.hero)
                                    .frame(width: 3)
                                    .clipShape(Capsule())
                                Text("\u{201C}\(ex)\u{201D}")
                                    .font(.lexisBody)
                                    .italic()
                                    .foregroundColor(.textSecondary)
                                    .lineSpacing(6)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    // Progress status chip
                    if let p = word.progress?.status, !p.isEmpty {
                        Text(p.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.lexisCaption)
                            .foregroundColor(.skyBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.skyBlue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .padding(.bottom, Spacing.xxxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfaceCard.opacity(0.96))
    }
}
