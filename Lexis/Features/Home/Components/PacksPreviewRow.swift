import SwiftUI

struct PacksPreviewRow: View {
    let packs: [PackSummaryResponse]
    let packsAreLoading: Bool
    let packsLoadCompleted: Bool
    let onStartExploring: () -> Void
    let onBrowsePack: (PackSummaryResponse) -> Void
    let onBrowseAll: () -> Void

    private var showShimmer: Bool {
        packsAreLoading && !packsLoadCompleted
    }

    private var showLibraryFallback: Bool {
        packsLoadCompleted && packs.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Word Packs")
                    .font(.lexisH3)
                    .foregroundColor(.moonPearl)
                Spacer()
                if !showLibraryFallback, !packs.isEmpty {
                    Button {
                        Haptics.impact(.light)
                        onBrowseAll()
                    } label: {
                        Text("Browse all")
                            .font(.lexisCaption)
                            .foregroundColor(.cobaltBlue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.xl)

            if showShimmer {
                ShimmerCard(height: 110)
                    .padding(.horizontal, Spacing.xl)
            } else if showLibraryFallback {
                WordLibraryFallbackCard(onStartExploring: onStartExploring)
                    .padding(.horizontal, Spacing.xl)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.md) {
                        Spacer().frame(width: Spacing.lg)
                        ForEach(packs) { pack in
                            PackCard(pack: pack, onBrowse: { onBrowsePack(pack) })
                        }
                        Spacer().frame(width: Spacing.lg)
                    }
                }
            }
        }
    }
}

// MARK: - Empty packs: global library

struct WordLibraryFallbackCard: View {
    let onStartExploring: () -> Void

    var body: some View {
        Button {
            Haptics.impact(.medium)
            onStartExploring()
        } label: {
            HStack(spacing: Spacing.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.md)
                        .fill(LinearGradient.hero.opacity(0.2))
                        .frame(width: 56, height: 56)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(LinearGradient.hero)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Word Library")
                        .font(.lexisH3)
                        .foregroundColor(.moonPearl)
                    Text("No curated packs yet — learn from your personal word pool.")
                        .font(.lexisCaption)
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.leading)
                    Text("Start exploring")
                        .font(.lexisCaptionM)
                        .foregroundColor(.cobaltBlue)
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textTertiary)
            }
            .padding(Spacing.lg)
            .background(Color.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Color.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct PackCard: View {
    let pack: PackSummaryResponse
    let onBrowse: () -> Void
    @State private var showSubscription = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                packTypeIcon
                Spacer()
                if pack.isPremium && !pack.access.hasAccess {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.amberGlow)
                }
            }

            Spacer()

            Text(pack.title)
                .font(.lexisH3)
                .foregroundColor(.moonPearl)
                .lineLimit(2)

            HStack(spacing: 4) {
                Image(systemName: "book.closed")
                    .font(.lexisCaption)
                    .foregroundColor(.textSecondary)
                Text("\(pack.wordCount) words")
                    .font(.lexisCaption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(Spacing.lg)
        .frame(width: 148, height: 130)
        .background(
            pack.isPremium && !pack.access.hasAccess
            ? AnyView(Color.surfaceCard)
            : AnyView(LinearGradient(
                colors: [packGradientColor.opacity(0.18), Color.surfaceCard],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(
                    pack.isPremium && !pack.access.hasAccess
                    ? Color.amberGlow.opacity(0.25)
                    : Color.glassBorder,
                    lineWidth: 1
                )
        )
        .onTapGesture {
            if pack.isPremium && !pack.access.hasAccess {
                showSubscription = true
            } else {
                Haptics.impact(.medium)
                onBrowse()
            }
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView()
        }
    }

    private var packTypeIcon: some View {
        let (emoji, _): (String, Color) = {
            switch pack.packType?.lowercased() {
            case "exam":   return ("📝", .cobaltBlue)
            case "topic":  return ("💡", .cobaltBlue)
            case "daily":  return ("⭐️", .amberGlow)
            default:       return ("📚", .textSecondary)
            }
        }()
        return Text(emoji).font(.system(size: 18))
    }

    private var packGradientColor: Color {
        switch pack.packType?.lowercased() {
        case "exam":   return .cobaltBlue
        case "topic":  return .cobaltBlue
        case "daily":  return .amberGlow
        default:       return .cobaltBlue
        }
    }
}
