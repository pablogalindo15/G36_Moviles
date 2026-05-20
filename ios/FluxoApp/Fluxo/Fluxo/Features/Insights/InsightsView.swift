import SwiftUI
import Combine

struct InsightsView: View {
    @StateObject private var viewModel: InsightsViewModel

    init(viewModel: InsightsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.bundle == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage = viewModel.errorMessage, viewModel.bundle == nil {
                    VStack(spacing: 16) {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundColor(FluxoTheme.secondaryText)
                            .multilineTextAlignment(.center)
                        Button("Try again") {
                            Task { await viewModel.load() }
                        }
                        .foregroundColor(FluxoTheme.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if let computedAt = viewModel.bundle?.lastComputedAt {
                                Text("Updated \(computedAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))")
                                    .font(.caption)
                                    .foregroundColor(FluxoTheme.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }

                            if let bundle = viewModel.bundle, bundle.isStale {
                                Text(ConnectivitySupport.cachedContentMessage())
                                    .font(.footnote)
                                    .foregroundColor(FluxoTheme.secondaryText)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(FluxoTheme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            CategoryCycleComparisonCard(data: viewModel.bundle?.cycleComparison)
                            CategoryStreaksCard(data: viewModel.bundle?.streaks)
                            BiggestExpenseCard(data: viewModel.bundle?.biggestExpense)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .refreshable { await viewModel.refresh() }
                }
            }
            .background(FluxoTheme.background.ignoresSafeArea())
            .navigationTitle("Insights")
        }
        .task {
            if viewModel.bundle == nil {
                await viewModel.load()
            }
        }
    }
}
