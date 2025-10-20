import Foundation

final class GamificationEngine {
    static let shared = GamificationEngine()

    private let store: GamificationStore
    private let calendar: Calendar

    init(store: GamificationStore = .shared, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    // MARK: - Public API

    @discardableResult
    func processTaskCompletion(_ task: TaskItem, userID: String = ShoppingUser.current.id) -> GamificationResult? {
        guard task.isCompleted, let completedAt = task.completedAt else { return nil }
        let due = task.dueDate
        let base = 50
        var delta = base

        if completedAt <= due {
            delta += 20
            let hoursEarly = max(0, Int((due.timeIntervalSince(completedAt)) / 3600))
            delta += min(50, hoursEarly)
        } else {
            let hoursLate = Int((completedAt.timeIntervalSince(due)) / 3600)
            let penalty = min(50, hoursLate * 2)
            delta -= penalty
        }
        delta = max(0, delta)

        var profile = store.loadProfile(for: userID)
        profile.points += delta
        profile.tasksCompleted += 1

        // Update streak based on calendar days
        let completionDay = calendar.startOfDay(for: completedAt)
        if let lastDay = profile.lastTaskCompletionDay {
            let gap = calendar.dateComponents([.day], from: lastDay, to: completionDay).day ?? 0
            if gap == 0 {
                // same day, keep streak as is
            } else if gap == 1 {
                profile.streak += 1
            } else {
                profile.streak = 1
            }
        } else {
            profile.streak = 1
        }
        profile.lastTaskCompletionDay = completionDay

        // Unlock achievements
        let unlocked = evaluateAchievements(for: profile)
        profile.achievements.append(contentsOf: unlocked)

        store.saveProfile(profile)

        let message = makeFeedbackMessage(points: delta, newAchievements: unlocked)
        return GamificationResult(addedPoints: delta, newAchievements: unlocked, message: message)
    }

    @discardableResult
    func processPurchase(_ item: ShoppingItem, userID: String = ShoppingUser.current.id) -> GamificationResult {
        // Simple rule: 10 points per purchase regardless of quantity
        let delta = 10
        var profile = store.loadProfile(for: userID)
        profile.points += delta
        profile.purchasesMade += 1

        let unlocked = evaluateAchievements(for: profile)
        profile.achievements.append(contentsOf: unlocked)

        store.saveProfile(profile)
        let message = makeFeedbackMessage(points: delta, newAchievements: unlocked)
        return GamificationResult(addedPoints: delta, newAchievements: unlocked, message: message)
    }

    func profile(for userID: String = ShoppingUser.current.id) -> GamificationProfile {
        store.loadProfile(for: userID)
    }

    func gratitudeSuggestions(for userID: String = ShoppingUser.current.id) -> [String] {
        let profile = store.loadProfile(for: userID)
        var suggestions: [String] = []

        if profile.streak >= 7 {
            suggestions.append("Plan a family movie night to celebrate your streak!")
        } else if profile.streak >= 3 {
            suggestions.append("Surprise a teammate with a thank-you coffee for keeping the streak going.")
        }

        if profile.tasksCompleted >= 10 {
            suggestions.append("Write a short note thanking your household for their effort.")
        }

        if profile.purchasesMade >= 5 {
            suggestions.append("Send a quick 'thanks for picking that up' to whoever shopped last.")
        }

        suggestions.append("Take a moment to appreciate your progress today.")
        return Array(Set(suggestions)).sorted()
    }

    // MARK: - Helpers

    private func makeFeedbackMessage(points: Int, newAchievements: [Achievement]) -> String {
        var parts: [String] = []
        parts.append("🎯 +\(points) points")
        if !newAchievements.isEmpty {
            let earned = newAchievements.map { "\($0.icon) \($0.name)" }.joined(separator: ", ")
            parts.append("Unlocked: \(earned)")
        }
        return parts.joined(separator: " • ")
    }

    private func evaluateAchievements(for profile: GamificationProfile) -> [Achievement] {
        let now = Date()
        let existingKeys = Set(profile.achievements.map { $0.key })
        var unlocked: [Achievement] = []
        for definition in Self.achievementCatalog {
            guard !existingKeys.contains(definition.key) else { continue }
            if meets(definition.criterion, with: profile) {
                unlocked.append(Achievement(key: definition.key, name: definition.name, icon: definition.icon, unlockedAt: now))
            }
        }
        return unlocked
    }

    private func meets(_ criterion: AchievementDefinition.Criterion, with profile: GamificationProfile) -> Bool {
        switch criterion {
        case .points(let threshold):
            return profile.points >= threshold
        case .tasksCompleted(let threshold):
            return profile.tasksCompleted >= threshold
        case .streak(let threshold):
            return profile.streak >= threshold
        case .purchases(let threshold):
            return profile.purchasesMade >= threshold
        }
    }
}

extension GamificationEngine {
    static let achievementCatalog: [AchievementDefinition] = [
        AchievementDefinition(key: "FIRST_TASK", name: "First Task", icon: "✨", criterion: .tasksCompleted(1)),
        AchievementDefinition(key: "POINTS_BRONZE", name: "Bronze", icon: "🥉", criterion: .points(100)),
        AchievementDefinition(key: "POINTS_SILVER", name: "Silver", icon: "🥈", criterion: .points(500)),
        AchievementDefinition(key: "POINTS_GOLD", name: "Gold", icon: "🥇", criterion: .points(1000)),
        AchievementDefinition(key: "STREAK_3", name: "3-Day Streak", icon: "🔥", criterion: .streak(3)),
        AchievementDefinition(key: "STREAK_7", name: "7-Day Streak", icon: "💥", criterion: .streak(7)),
        AchievementDefinition(key: "SHOPPER_5", name: "Active Shopper", icon: "🛒", criterion: .purchases(5))
    ]
}
