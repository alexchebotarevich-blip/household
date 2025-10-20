import SwiftUI

struct RewardsView: View {
    @Environment(\.appTheme) private var theme
    @State private var profile: GamificationProfile = GamificationEngine.shared.profile()
    @State private var suggestions: [String] = GamificationEngine.shared.gratitudeSuggestions()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.large) {
                header
                pointsCard
                achievementsSection
                streakCard
                suggestionsSection
            }
            .padding(theme.spacing.large)
        }
        .background(theme.colors.background.ignoresSafeArea())
        .navigationTitle("Rewards")
        .onAppear(perform: reload)
    }

    private var header: some View {
        HStack(spacing: theme.spacing.medium) {
            Text("🎉")
                .font(.system(size: 42))
            VStack(alignment: .leading) {
                Text("Great job!")
                    .font(theme.typography.title)
                Text("Here are your latest rewards and milestones.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            }
            Spacer()
        }
        .padding(theme.spacing.medium)
        .background(theme.colors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.small, style: .continuous))
    }

    private var pointsCard: some View {
        HStack(spacing: theme.spacing.medium) {
            Image(systemName: "star.fill").foregroundStyle(theme.colors.primary)
            VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
                Text("Points")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
                Text("\(profile.points)")
                    .font(theme.typography.body.weight(.semibold))
            }
            Spacer()
        }
        .padding(theme.spacing.medium)
        .background(theme.colors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.small, style: .continuous))
    }

    private var achievementsSection: some View {
        AppFormSection(title: "Achievements") {
            if profile.achievements.isEmpty {
                Text("Earn points and complete tasks to unlock achievements.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
                    .padding(.vertical, theme.spacing.small)
            } else {
                ForEach(profile.achievements.sorted(by: { $0.unlockedAt > $1.unlockedAt })) { achievement in
                    HStack(spacing: theme.spacing.medium) {
                        Text(achievement.icon)
                            .font(.system(size: 22))
                        VStack(alignment: .leading) {
                            Text(achievement.name)
                                .font(theme.typography.body.weight(.semibold))
                            Text("Unlocked \(achievement.unlockedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, theme.spacing.xSmall)
                }
            }
        }
    }

    private var streakCard: some View {
        HStack(spacing: theme.spacing.medium) {
            Image(systemName: "flame.fill").foregroundStyle(theme.colors.primary)
            VStack(alignment: .leading, spacing: theme.spacing.xSmall) {
                Text("Streak")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
                Text("\(profile.streak) days")
                    .font(theme.typography.body.weight(.semibold))
            }
            Spacer()
        }
        .padding(theme.spacing.medium)
        .background(theme.colors.surface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: theme.spacing.small, style: .continuous))
    }

    private var suggestionsSection: some View {
        AppFormSection(title: "Gratitude suggestions") {
            if suggestions.isEmpty {
                Text("Keep going! Suggestions will appear as you make progress.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            } else {
                ForEach(suggestions, id: \.self) { suggestion in
                    HStack(alignment: .top, spacing: theme.spacing.medium) {
                        Image(systemName: "hands.clap")
                            .foregroundStyle(theme.colors.primary)
                        Text(suggestion)
                            .font(theme.typography.body)
                        Spacer()
                    }
                    .padding(.vertical, theme.spacing.xSmall)
                }
            }
        }
    }

    private func reload() {
        profile = GamificationEngine.shared.profile()
        suggestions = GamificationEngine.shared.gratitudeSuggestions()
    }
}

#Preview {
    NavigationStack {
        RewardsView()
            .environment(\.appTheme, .default)
    }
}
