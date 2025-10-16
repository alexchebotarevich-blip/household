import Foundation
import Combine
import CombineExt

final class HomeViewModel: ObservableObject {
    @Published private(set) var greeting: String = ""
    @Published private(set) var upcomingTasks: [TaskItem] = []
    @Published private(set) var shoppingHighlights: [ShoppingItem] = []

    private let environment: AppEnvironment
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment = AppEnvironment()) {
        self.environment = environment
        bindEnvironment()
        loadPreviewData()
        environment.signInIfNeeded()
    }

    func onAppear() {
        environment.signInIfNeeded()
    }

    private func bindEnvironment() {
        environment.$isAuthenticated
            .removeDuplicates()
            .filter { $0 }
            .map { _ in "Welcome back" }
            .weakAssign(to: \HomeViewModel.greeting, on: self)
            .store(in: &cancellables)
    }

    private func loadPreviewData() {
        Just(TaskItem.samples)
            .combineLatest(Just(ShoppingItem.samples))
            .delay(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .sink { [weak self] tasks, items in
                self?.upcomingTasks = Array(tasks.prefix(3))
                self?.shoppingHighlights = Array(items.prefix(2))
                if self?.greeting.isEmpty ?? true {
                    self?.greeting = "Let's plan your day"
                }
            }
            .store(in: &cancellables)
    }
}
