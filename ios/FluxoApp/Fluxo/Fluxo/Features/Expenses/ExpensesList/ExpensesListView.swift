import SwiftUI

struct ExpensesListView: View {
    @StateObject private var viewModel: ExpensesListViewModel
    private let receiptService: ReceiptImageService
    private let cameraFacade: CameraFacade
    @State private var expenseToDelete: Expense? = nil
    @State private var showDeleteConfirmation = false

    init(
        expensesService: ExpensesApplicationService,
        planService: PlanApplicationService,
        receiptService: ReceiptImageService,
        cameraFacade: CameraFacade
    ) {
        _viewModel = StateObject(
            wrappedValue: ExpensesListViewModel(
                expensesService: expensesService,
                planService: planService
            )
        )
        self.receiptService = receiptService
        self.cameraFacade = cameraFacade
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .error(let message):
                VStack(spacing: 12) {
                    Text(message)
                        .foregroundColor(FluxoTheme.error)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await viewModel.load() }
                    }
                    .foregroundColor(FluxoTheme.primary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                listContent
            }
        }
        .navigationTitle("My expenses")
        .navigationBarTitleDisplayMode(.large)
        .background(FluxoTheme.background.ignoresSafeArea())
        .searchable(text: $viewModel.searchText, prompt: "Search by note")
        .toolbar { toolbarContent }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .confirmationDialog(
            "Delete this expense?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let expense = expenseToDelete {
                    Task { await viewModel.delete(expense: expense) }
                    expenseToDelete = nil
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Couldn't delete expense", isPresented: Binding(
            get: { viewModel.deleteError != nil },
            set: { if !$0 { viewModel.deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.deleteError = nil }
        } message: {
            Text(viewModel.deleteError ?? "")
        }
    }

    @ViewBuilder private var listContent: some View {
        VStack(spacing: 0) {
            Picker("Scope", selection: $viewModel.scope) {
                Text("Current cycle").tag(ExpensesListViewModel.Scope.currentCycle)
                Text("All").tag(ExpensesListViewModel.Scope.all)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .disabled(!viewModel.isCycleAvailable)

            if viewModel.filteredExpenses.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(FluxoTheme.secondaryText)
                    Text(
                        viewModel.scope == .currentCycle
                            ? "No expenses in this cycle"
                            : "No expenses recorded yet"
                    )
                    .font(.subheadline)
                    .foregroundColor(FluxoTheme.secondaryText)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(viewModel.filteredExpenses) { expense in
                        NavigationLink {
                            ExpenseDetailView(
                                expense: expense,
                                expensesService: viewModel.expensesService,
                                receiptService: receiptService,
                                cameraFacade: cameraFacade
                            )
                        } label: {
                            ExpenseRow(expense: expense)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                expenseToDelete = expense
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Category", selection: $viewModel.selectedCategory) {
                    Text("All categories").tag(ExpenseCategory?.none)
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        Label(category.displayName, systemImage: category.icon)
                            .tag(category as ExpenseCategory?)
                    }
                }
            } label: {
                Image(
                    systemName: viewModel.selectedCategory == nil
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill"
                )
                .foregroundColor(FluxoTheme.primary)
            }
        }
    }
}
