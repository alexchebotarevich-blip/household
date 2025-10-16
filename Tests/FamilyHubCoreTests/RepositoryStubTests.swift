import XCTest
@testable import FamilyHubCore

final class RepositoryStubTests: XCTestCase {
    private var store: InMemoryRepositoryStore!
    private var listenerCenter: FirestoreListenerCenter!

    override func setUp() {
        super.setUp()
        store = InMemoryRepositoryStore()
        listenerCenter = FirestoreListenerCenter(deliveryQueue: DispatchQueue(label: "RepositoryStubTests.delivery"))
    }

    override func tearDown() {
        store = nil
        listenerCenter = nil
        super.tearDown()
    }

    func testAuthenticationRepositoryLifecycle() throws {
        let repository = InMemoryAuthenticationRepository(store: store)

        let signedUp = try repository.signUp(email: "jane@example.com", password: "password", displayName: "Jane")
        XCTAssertEqual(repository.currentUser?.id, signedUp.id)

        try repository.signOut()
        XCTAssertNil(repository.currentUser)

        let signedIn = try repository.signIn(email: signedUp.email, password: "password")
        XCTAssertEqual(signedIn.id, signedUp.id)
    }

    func testAuthenticationRepositoryNotifiesListeners() throws {
        let repository = InMemoryAuthenticationRepository(store: store)
        let expectation = expectation(description: "Auth listener notified")
        expectation.expectedFulfillmentCount = 2 // initial nil + signed in user

        let token = repository.observeAuthChanges { user in
            if user == nil {
                expectation.fulfill()
            } else if user?.email == "jane@example.com" {
                expectation.fulfill()
            }
        }

        _ = try repository.signUp(email: "jane@example.com", password: "password", displayName: "Jane")
        wait(for: [expectation], timeout: 1.0)
        token.cancel()
    }

    func testTaskRepositoryPublishesRealtimeEvents() throws {
        let familyID = "family_42"
        let repository = InMemoryTaskRepository(store: store, listenerCenter: listenerCenter)
        var receivedAddition = false
        var receivedModification = false
        var receivedRemoval = false
        let eventsExpectation = expectation(description: "Received all task events")

        let token = repository.observeTaskEvents(for: familyID) { result in
            guard case let .success(events) = result else { return }
            for event in events {
                switch event {
                case .added(let task) where task.id == "task_1":
                    receivedAddition = true
                case .modified(let task) where task.id == "task_1":
                    receivedModification = true
                case .removed(let task) where task.id == "task_1":
                    receivedRemoval = true
                default:
                    break
                }
            }

            if receivedAddition && receivedModification && receivedRemoval {
                eventsExpectation.fulfill()
            }
        }

        let timestamp = Date()
        let initialTask = TaskItem(
            id: "task_1",
            familyID: familyID,
            name: "Clean kitchen",
            details: "Tidy up after dinner",
            dueDate: timestamp.addingTimeInterval(3_600),
            status: .pending,
            priority: .medium,
            assigneeIDs: ["user_1"],
            repeatRule: nil,
            checklist: [],
            createdBy: "user_1",
            createdAt: timestamp,
            updatedAt: timestamp,
            completedAt: nil
        )

        try repository.create(initialTask)

        var updatedTask = initialTask
        updatedTask.status = .completed
        updatedTask.updatedAt = timestamp.addingTimeInterval(1_800)
        try repository.update(updatedTask)

        try repository.delete(taskID: initialTask.id, familyID: familyID)

        wait(for: [eventsExpectation], timeout: 1.0)
        token.cancel()
    }

    func testShoppingRepositoryPublishesRealtimeEvents() throws {
        let familyID = "family_42"
        let repository = InMemoryShoppingRepository(store: store, listenerCenter: listenerCenter)
        let expectation = expectation(description: "Shopping events received")
        var receivedAdded = false
        var receivedRemoved = false

        let token = repository.observeShoppingEvents(for: familyID) { result in
            guard case let .success(events) = result else { return }
            for event in events {
                switch event {
                case .added(let item) where item.id == "item_1":
                    receivedAdded = true
                case .removed(let item) where item.id == "item_1":
                    receivedRemoved = true
                default:
                    break
                }
            }

            if receivedAdded && receivedRemoved {
                expectation.fulfill()
            }
        }

        let timestamp = Date()
        let item = ShoppingItem(
            id: "item_1",
            familyID: familyID,
            name: "Milk",
            quantity: 1,
            unit: "carton",
            notes: nil,
            status: .pending,
            createdBy: "user_1",
            assigneeID: "user_2",
            purchasedBy: nil,
            createdAt: timestamp,
            updatedAt: nil,
            purchasedAt: nil
        )

        try repository.create(item)
        try repository.delete(itemID: item.id, familyID: familyID)

        wait(for: [expectation], timeout: 1.0)
        token.cancel()
    }
}
