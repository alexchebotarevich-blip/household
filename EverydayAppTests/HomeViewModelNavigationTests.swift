import XCTest
import Combine
@testable import EverydayApp

final class HomeViewModelNavigationTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testRouteUpdatesWhenNavigating() {
        let taskRepository = StubTaskRepository(tasks: TaskItem.samples)
        let shoppingRepository = StubShoppingRepository()
        let analyticsService = HouseholdAnalyticsService(
            taskRepository: taskRepository,
            shoppingRepository: shoppingRepository,
            now: { Date() }
        )
        let environment = AppEnvironment(configuration: AppConfiguration(), authService: StubAuthService())
        let viewModel = HomeViewModel(
            environment: environment,
            taskRepository: taskRepository,
            shoppingRepository: shoppingRepository,
            analyticsService: analyticsService
        )

        XCTAssertNil(viewModel.route)

        viewModel.showHistory()
        XCTAssertEqual(viewModel.route, .history)

        viewModel.clearRoute()
        XCTAssertNil(viewModel.route)

        viewModel.showAnalytics()
        XCTAssertEqual(viewModel.route, .analytics)
    }
}

// MARK: - Test Doubles

private final class StubAuthService: FirebaseAuthServicing {
    private let subject = CurrentValueSubject<Bool, Never>(true)

    var authenticationState: AnyPublisher<Bool, Never> {
        subject.eraseToAnyPublisher()
    }

    func signInAnonymously() -> AnyPublisher<Bool, Error> {
        Just(true)
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

private final class StubTaskRepository: TaskRepository {
    private var tasks: [TaskItem]
    private let subject: CurrentValueSubject<[TaskItem], Never>

    init(tasks: [TaskItem]) {
        self.tasks = tasks
        self.subject = CurrentValueSubject(tasks)
    }

    var updates: AnyPublisher<[TaskItem], Never> {
        subject.eraseToAnyPublisher()
    }

    @discardableResult
    func add(_ task: TaskItem) -> TaskItem {
        tasks.append(task)
        subject.send(tasks)
        return task
    }

    @discardableResult
    func update(id: UUID, mutation: (inout TaskItem) -> Void) -> TaskItem? {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return nil }
        mutation(&tasks[index])
        subject.send(tasks)
        return tasks[index]
    }

    func replaceAll(_ tasks: [TaskItem]) {
        self.tasks = tasks
        subject.send(tasks)
    }

    func task(with id: UUID) -> TaskItem? {
        tasks.first { $0.id == id }
    }
}

private final class StubShoppingRepository: ShoppingListRepository {
    private let itemsSubject: CurrentValueSubject<[ShoppingItem], Never>
    private let activitySubject: CurrentValueSubject<[ShoppingActivityLogEntry], Never>

    init(items: [ShoppingItem] = [], activities: [ShoppingActivityLogEntry] = []) {
        self.itemsSubject = CurrentValueSubject(items)
        self.activitySubject = CurrentValueSubject(activities)
    }

    var updates: AnyPublisher<[ShoppingItem], Never> {
        itemsSubject.eraseToAnyPublisher()
    }

    var activityUpdates: AnyPublisher<[ShoppingActivityLogEntry], Never> {
        activitySubject.eraseToAnyPublisher()
    }

    func add(_ item: ShoppingItem) {
        var current = itemsSubject.value
        current.append(item)
        itemsSubject.send(current)
    }

    func update(_ item: ShoppingItem) {
        var current = itemsSubject.value
        if let index = current.firstIndex(where: { $0.id == item.id }) {
            current[index] = item
            itemsSubject.send(current)
        }
    }

    @discardableResult
    func delete(id: UUID, actor: ShoppingUser) -> ShoppingItem? {
        var current = itemsSubject.value
        guard let index = current.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = current.remove(at: index)
        itemsSubject.send(current)
        return removed
    }

    func restore(_ item: ShoppingItem) {
        add(item)
    }

    func markPurchased(id: UUID, by user: ShoppingUser) -> ShoppingItem? {
        nil
    }

    func markPending(id: UUID) -> ShoppingItem? {
        nil
    }

    func item(with id: UUID) -> ShoppingItem? {
        itemsSubject.value.first { $0.id == id }
    }
}
