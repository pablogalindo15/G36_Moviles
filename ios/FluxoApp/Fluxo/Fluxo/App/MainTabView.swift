import SwiftUI

struct MainTabView: View {
    let container: AppContainer
    let onSignOut: () -> Void

    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Dashboard", systemImage: "chart.bar.fill", value: 0) {
                DashboardView(
                    viewModel: DashboardViewModel(
                        planService: container.planService,
                        expensesService: container.expensesService,
                        comparativeSpendingService: container.comparativeSpendingService,
                        topCategoriesService: container.topCategoriesService,
                        savingsProjectionService: container.savingsProjectionService,
                        preferencesAdapter: container.preferencesAdapter,
                        expensesFileAdapter: container.expensesFileAdapter,
                        onSignOut: onSignOut
                    )
                )
            }
            Tab("Expenses", systemImage: "list.bullet", value: 1) {
                NavigationStack {
                    ExpensesListView(
                        expensesService: container.expensesService,
                        planService: container.planService
                    )
                }
            }
            Tab("Insights", systemImage: "chart.line.uptrend.xyaxis", value: 2) {
                InsightsView(
                    viewModel: InsightsViewModel(insightsService: container.insightsService)
                )
            }
        }
    }
}
