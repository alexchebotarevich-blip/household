import Foundation

enum AppDependencies {
    static let taskRepository: TaskRepository = InMemoryTaskRepository.shared
    static let shoppingRepository: ShoppingListRepository = OfflineFirstShoppingRepository.shared
    static let analyticsService = HouseholdAnalyticsService(
        taskRepository: taskRepository,
        shoppingRepository: shoppingRepository
    )
}
