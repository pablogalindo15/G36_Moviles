import Foundation
import Combine

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published private(set) var bundle: InsightsBundle? = nil
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String? = nil

    private let insightsService: InsightsApplicationService

    init(insightsService: InsightsApplicationService) {
        self.insightsService = insightsService
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        let result = await insightsService.loadAllInsights()
        bundle = result
        isLoading = false
        if result.cycleComparison == nil && result.streaks == nil && result.biggestExpense == nil {
            errorMessage = InsightLoadError.noCachedData.errorDescription
        }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        let result = await Task.detached(priority: .userInitiated) { [insightsService] in
            await insightsService.loadAllInsights(forceRefresh: true)
        }.value
        bundle = result
        isLoading = false
        if result.cycleComparison == nil && result.streaks == nil && result.biggestExpense == nil {
            errorMessage = InsightLoadError.noCachedData.errorDescription
        }
    }
}
