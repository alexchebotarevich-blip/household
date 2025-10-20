import Foundation
import Combine

final class HistoryViewModel: ObservableObject {
    @Published private(set) var entries: [HouseholdHistoryEntry] = []
    @Published private(set) var members: [String] = []
    @Published private(set) var availableTaskTypes: [TaskItem.Kind] = TaskItem.Kind.allCases
    @Published var selectedMember: String? = nil
    @Published var selectedTaskType: TaskItem.Kind? = nil

    private let analyticsService: HouseholdAnalyticsService
    private var cancellables = Set<AnyCancellable>()

    init(analyticsService: HouseholdAnalyticsService = AppDependencies.analyticsService) {
        self.analyticsService = analyticsService
        bind()
    }

    func clearFilters() {
        selectedMember = nil
        selectedTaskType = nil
    }

    private func bind() {
        analyticsService.$history
            .combineLatest(
                $selectedMember.removeDuplicates(),
                $selectedTaskType.removeDuplicates()
            )
            .map { entries, member, taskType -> [HouseholdHistoryEntry] in
                entries.filter { entry in
                    let matchesMember = member.map { entry.member == $0 } ?? true
                    if let taskType {
                        return matchesMember && entry.taskType == taskType
                    }
                    return matchesMember
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] filtered in
                self?.entries = filtered
            }
            .store(in: &cancellables)

        analyticsService.$history
            .receive(on: DispatchQueue.main)
            .sink { [weak self] allEntries in
                self?.updateFilters(with: allEntries)
            }
            .store(in: &cancellables)
    }

    private func updateFilters(with entries: [HouseholdHistoryEntry]) {
        let memberSet = Set(entries.map(\.member))
        let sortedMembers = memberSet.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        members = sortedMembers
        if let selectedMember, !memberSet.contains(selectedMember) {
            self.selectedMember = nil
        }

        let taskTypeSet = Set(entries.compactMap(\.taskType))
        let sortedTypes = TaskItem.Kind.allCases.filter { taskTypeSet.contains($0) }
        availableTaskTypes = sortedTypes
        if let selectedTaskType, !taskTypeSet.contains(selectedTaskType) {
            self.selectedTaskType = nil
        }
    }
}
