import XCTest
import Combine
@testable import EverydayApp

final class ShoppingViewModelTests: XCTestCase {
    private var cacheDirectory: URL!
    private var repository: OfflineFirstShoppingRepository!
    private var viewModel: ShoppingViewModel!
    private var cancellables: Set<AnyCancellable> = []

    override func setUp() {
        super.setUp()
        cacheDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        repository = OfflineFirstShoppingRepository(cache: ShoppingListCache(directory: cacheDirectory))
        viewModel = ShoppingViewModel(repository: repository, user: ShoppingUser(id: "test-user", displayName: "Test User"))
    }

    override func tearDown() {
        cancellables.removeAll()
        if let cacheDirectory {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
        repository = nil
        viewModel = nil
        cacheDirectory = nil
        super.tearDown()
    }

    func testAddingItemCreatesPendingEntry() {
        let expectation = expectation(description: "Pending items updated")

        viewModel.$pendingItems
            .dropFirst()
            .sink { items in
                if items.contains(where: { $0.name == "Coffee Beans" }) {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        var form = viewModel.makeNewFormState()
        form.name = "Coffee Beans"
        form.quantity = 2
        form.category = "Pantry"
        form.assignee = "Sam"
        form.notes = "Whole bean"

        viewModel.save(form: form)

        wait(for: [expectation], timeout: 1)

        XCTAssertEqual(viewModel.pendingItems.count, 1)
        let item = viewModel.pendingItems.first
        XCTAssertEqual(item?.assignee, "Sam")
        XCTAssertEqual(item?.notes, "Whole bean")
        XCTAssertEqual(item?.category, "Pantry")
        XCTAssertEqual(item?.quantity, 2)
    }

    func testMarkingItemPurchasedMovesToPurchasedAndLogs() {
        let addExpectation = expectation(description: "Item added")

        viewModel.$pendingItems
            .dropFirst()
            .sink { items in
                if !items.isEmpty {
                    addExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        var form = viewModel.makeNewFormState()
        form.name = "Almond Milk"
        form.category = "Dairy"
        form.assignee = "Jordan"
        viewModel.save(form: form)

        wait(for: [addExpectation], timeout: 1)

        guard let item = viewModel.pendingItems.first else {
            XCTFail("Expected pending item")
            return
        }

        let purchaseExpectation = expectation(description: "Item purchased")
        let historyExpectation = expectation(description: "History updated")

        viewModel.$purchasedItems
            .dropFirst()
            .sink { items in
                if items.contains(where: { $0.id == item.id }) {
                    purchaseExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.$purchaseHistory
            .dropFirst()
            .sink { entries in
                if entries.contains(where: { $0.itemID == item.id && $0.action == .purchased }) {
                    historyExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.togglePurchased(for: item)

        wait(for: [purchaseExpectation, historyExpectation], timeout: 1)

        XCTAssertTrue(viewModel.purchasedItems.contains(where: { $0.id == item.id && $0.purchasedBy == "Test User" }))
        XCTAssertEqual(viewModel.purchaseHistory.first?.actorName, "Test User")
        XCTAssertEqual(viewModel.purchaseHistory.first?.action, .purchased)
    }

    func testDeletingItemPresentsUndoAndRestores() {
        let addExpectation = expectation(description: "Item added")

        viewModel.$pendingItems
            .dropFirst()
            .sink { items in
                if !items.isEmpty {
                    addExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        var form = viewModel.makeNewFormState()
        form.name = "Tomatoes"
        form.category = "Produce"
        viewModel.save(form: form)

        wait(for: [addExpectation], timeout: 1)

        guard let item = viewModel.pendingItems.first else {
            XCTFail("Expected pending item")
            return
        }

        let removalExpectation = expectation(description: "Item removed")
        let restoreExpectation = expectation(description: "Item restored")

        viewModel.$pendingItems
            .dropFirst()
            .sink { [weak viewModel] items in
                if items.isEmpty {
                    removalExpectation.fulfill()
                } else if items.contains(where: { $0.id == item.id }) && viewModel?.undoPrompt == nil {
                    restoreExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        viewModel.delete(item)

        wait(for: [removalExpectation], timeout: 1)
        XCTAssertNotNil(viewModel.undoPrompt)

        viewModel.undoLastDeletion()

        wait(for: [restoreExpectation], timeout: 1)
        XCTAssertTrue(viewModel.pendingItems.contains(where: { $0.id == item.id }))
        XCTAssertNil(viewModel.undoPrompt)
    }
}
