import SwiftUI

struct ExpenseDetailView: View {
    @StateObject private var viewModel: ExpenseDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteDialog = false

    init(expense: Expense, expensesService: ExpensesApplicationService) {
        _viewModel = StateObject(
            wrappedValue: ExpenseDetailViewModel(
                expense: expense,
                expensesService: expensesService
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                amountSection
                categorySection
                if let note = viewModel.currentExpense.note, !note.isEmpty {
                    noteSection(note: note)
                }
                dateSection
                currencySection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(FluxoTheme.background.ignoresSafeArea())
        .navigationTitle("Expense detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .overlay {
            if viewModel.isDeleting {
                LoadingOverlay(title: "Deleting...")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            NavigationStack {
                EditExpenseView(
                    expense: viewModel.currentExpense,
                    expensesService: viewModel.expensesService,
                    onSaved: { updated in viewModel.handleSavedFromEdit(updated) }
                )
            }
        }
        .confirmationDialog(
            "Delete this expense?",
            isPresented: $showingDeleteDialog,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete() }
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
        .onChange(of: viewModel.didDelete) { _, newValue in
            if newValue { dismiss() }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 16) {
                Button {
                    showingDeleteDialog = true
                } label: {
                    Image(systemName: "trash")
                }
                .tint(.red)
                .disabled(viewModel.isDeleting)

                Button("Edit") {
                    showingEditSheet = true
                }
                .disabled(viewModel.isDeleting)
            }
        }
    }

    // MARK: - Sections

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Amount")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            Text("\(viewModel.currentExpense.currency) \(viewModel.currentExpense.amount.formatted(.number.precision(.fractionLength(2))))")
                .font(.title2.bold())
                .foregroundColor(FluxoTheme.titleText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Category")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            HStack(spacing: 8) {
                Image(systemName: viewModel.currentExpense.category.icon)
                    .foregroundColor(FluxoTheme.primary)
                Text(viewModel.currentExpense.category.displayName)
                    .font(.body)
                    .foregroundColor(FluxoTheme.titleText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func noteSection(note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Note")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            Text(note)
                .font(.body)
                .foregroundColor(FluxoTheme.titleText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Date")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            Text(viewModel.currentExpense.occurredAt.formatted(date: .long, time: .shortened))
                .font(.body)
                .foregroundColor(FluxoTheme.titleText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Currency")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            Text(viewModel.currentExpense.currency)
                .font(.body)
                .foregroundColor(FluxoTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FluxoTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
