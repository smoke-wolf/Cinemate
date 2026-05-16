import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var apiClient: APIClient
    let account: Account

    @State private var stats: AccountStats?
    @State private var showSettings = false
    @State private var showSwitchProfile = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Profile Header
                        VStack(spacing: 16) {
                            Circle()
                                .fill(account.color.gradient)
                                .frame(width: 90, height: 90)
                                .overlay {
                                    Text(account.initials)
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .shadow(color: account.color.opacity(0.4), radius: 16, x: 0, y: 6)

                            Text(account.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .padding(.top, 16)

                        // Watch Stats
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(title: "Watch Stats", icon: "film")

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                            ], spacing: 12) {
                                StatCard(
                                    title: "Watched",
                                    value: "\(stats?.watchedCount ?? 0)",
                                    icon: "film.fill",
                                    color: Theme.primaryGold
                                )
                                StatCard(
                                    title: "Watch Time",
                                    value: formatWatchTime(stats?.totalWatchTimeSeconds ?? 0),
                                    icon: "clock.fill",
                                    color: Theme.warmAmber
                                )
                                StatCard(
                                    title: "Favorites",
                                    value: "\(stats?.favoritesCount ?? 0)",
                                    icon: "heart.fill",
                                    color: Color(hex: "#F59E0B")
                                )
                                StatCard(
                                    title: "Total Plays",
                                    value: "\(stats?.totalPlays ?? 0)",
                                    icon: "play.circle.fill",
                                    color: Color(hex: "#A855F7")
                                )
                            }
                        }
                        .padding(.horizontal)

                        // Actions
                        VStack(spacing: 12) {
                            ProfileActionButton(
                                title: "Switch Profile",
                                icon: "person.2",
                                action: { showSwitchProfile = true }
                            )

                            ProfileActionButton(
                                title: "Settings",
                                icon: "gearshape",
                                action: { showSettings = true }
                            )
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Profile")
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(
                    account: account,
                    onSwitchAccount: { showSwitchProfile = true }
                )
            }
        }
        .task {
            await loadStats()
        }
    }

    private func loadStats() async {
        do {
            stats = try await apiClient.getAccountStats(accountId: Int(account.id) ?? 0)
        } catch {
            // API error — show zero stats
        }
    }

    private func formatWatchTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        if hours >= 24 {
            let days = hours / 24
            return "\(days)d \(hours % 24)h"
        }
        return "\(hours)h"
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Theme.primaryGold)
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.textPrimary)

            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .background(Theme.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
    }
}

struct ProfileActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding()
            .background(Theme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

#Preview {
    ProfileView(account: Account.previewAccounts[0])
        .environmentObject(APIClient())
        .preferredColorScheme(.dark)
}
