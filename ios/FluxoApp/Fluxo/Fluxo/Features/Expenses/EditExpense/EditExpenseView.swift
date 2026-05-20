import SwiftUI

struct EditExpenseView: View {
    @StateObject private var viewModel: EditExpenseViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        expense: Expense,
        expensesService: ExpensesApplicationService,
        onSaved: @escaping (Expense) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: EditExpenseViewModel(
                expense: expense,
                expensesService: expensesService,
                onSaved: onSaved
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                amountSection
                categorySection
                noteSection
                dateSection
                currencySection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(FluxoTheme.background.ignoresSafeArea())
        .navigationTitle("Edit expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .overlay {
            if viewModel.isSaving {
                LoadingOverlay(title: "Saving...")
            }
        }
        .alert("Couldn't save expense", isPresented: Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.saveError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.saveError = nil }
        } message: {
            Text(viewModel.saveError ?? "")
        }
        .onChange(of: viewModel.didSave) { _, newValue in
            if newValue { dismiss() }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Save") {
                Task { await viewModel.save() }
            }
            .disabled(!viewModel.canSave)
        }
    }

    // MARK: - Sections

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            TextField(
                "0.00",
                value: $viewModel.draftAmount,
                format: .number.precision(.fractionLength(2))
            )
            .keyboardType(.decimalPad)
            .font(.title2.bold())
            .foregroundColor(FluxoTheme.titleText)
            .padding(16)
            .background(FluxoTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            Picker("Category", selection: $viewModel.draftCategory) {
                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                    Label(category.displayName, systemImage: category.icon)
                        .tag(category)
                }
            }
            .pickerStyle(.menu)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FluxoTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            TextField("What was it for?", text: $viewModel.draftNote)
                .autocorrectionDisabled()
                .padding(16)
                .background(FluxoTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            DatePicker(
                "",
                selection: $viewModel.draftOccurredAt,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FluxoTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var currencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Currency")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            Text(viewModel.currency)
                .font(.body)
                .foregroundColor(FluxoTheme.secondaryText)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(FluxoTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
