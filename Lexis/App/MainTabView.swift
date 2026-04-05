import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)

                SettingsView()
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea(edges: .bottom)

            LexisTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Custom 2-tab bar

struct LexisTabBar: View {
    @Binding var selectedTab: Int

    private let items: [(icon: String, label: String)] = [
        ("house.fill", "Home"),
        ("gearshape.fill", "Settings"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    Haptics.selection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon)
                            .font(.system(size: 21, weight: selectedTab == index ? .semibold : .regular))
                            .foregroundStyle(selectedTab == index
                                ? AnyShapeStyle(LinearGradient.hero)
                                : AnyShapeStyle(Color.textSecondary)
                            )
                            .scaleEffect(selectedTab == index ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTab)

                        Text(item.label)
                            .font(.lexisCaptionM)
                            .foregroundColor(selectedTab == index ? .moonPearl : .textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, 20)
        .background(
            Color.deepNavy
                .overlay(
                    Rectangle()
                        .fill(Color.glassBorder)
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
}
