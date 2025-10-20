import Foundation

struct Achievement: Codable, Equatable, Identifiable {
    let key: String
    let name: String
    let icon: String
    let unlockedAt: Date

    var id: String { key }
}

struct AchievementDefinition: Equatable {
    enum Criterion: Equatable {
        case points(Int)
        case tasksCompleted(Int)
        case streak(Int)
        case purchases(Int)
    }

    let key: String
    let name: String
    let icon: String
    let criterion: Criterion
}

struct GamificationProfile: Codable, Equatable {
    var userID: String
    var points: Int
    var tasksCompleted: Int
    var purchasesMade: Int
    var streak: Int
    var lastTaskCompletionDay: Date?
    var achievements: [Achievement]

    init(userID: String,
         points: Int = 0,
         tasksCompleted: Int = 0,
         purchasesMade: Int = 0,
         streak: Int = 0,
         lastTaskCompletionDay: Date? = nil,
         achievements: [Achievement] = []) {
        self.userID = userID
        self.points = points
        self.tasksCompleted = tasksCompleted
        self.purchasesMade = purchasesMade
        self.streak = streak
        self.lastTaskCompletionDay = lastTaskCompletionDay
        self.achievements = achievements
    }
}

struct GamificationResult: Equatable {
    let addedPoints: Int
    let newAchievements: [Achievement]
    let message: String
}
