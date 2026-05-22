import SwiftUI

struct ExpenseDetailView: View {
    @StateObject private var viewModel: ExpenseDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteDialog = false

    init(
        expense: Expense,
        expensesService: ExpensesApplicationService,
        receiptService: ReceiptImageService,
        cameraFacade: CameraFacade
    ) {
        _viewModel = StateObject(
            wrappedValue: ExpenseDetailViewModel(
                expense: expense,
                expensesService: expensesService,
                receiptService: receiptService,
                cameraFacade: cameraFacade
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
                receiptSection
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
            if viewModel.isDeleting || viewModel.isUploadingReceipt {
                LoadingOverlay(title: viewModel.isDeleting ? "Deleting..." : "Uploading receipt...")
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
        .sheet(isPresented: $viewModel.isShowingReceiptPicker) {
            SystemImagePicker(sourceType: viewModel.pickerSourceType) { image in
                Task { await viewModel.handlePickedReceipt(image) }
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
        .alert("Couldn't load receipt", isPresented: Binding(
            get: { viewModel.receiptError != nil },
            set: { if !$0 { viewModel.receiptError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.receiptError = nil }
        } message: {
            Text(viewModel.receiptError ?? "")
        }
        .onChange(of: viewModel.didDelete) { _, newValue in
            if newValue { dismiss() }
        }
        .task {
            await viewModel.loadReceiptIfNeeded()
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

    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Receipt")
                    .font(.caption)
                    .foregroundColor(FluxoTheme.secondaryText)
                Spacer()
                Button(viewModel.receiptImage == nil ? "Add receipt" : "Replace receipt") {
                    viewModel.openReceiptCapture()
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(FluxoTheme.primary)
            }

            if viewModel.isLoadingReceipt && viewModel.receiptImage == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 160)
            } else if let receiptImage = viewModel.receiptImage {
                Image(uiImage: receiptImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 180)
                    .background(FluxoTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text(viewModel.receiptMessage ?? "No receipt attached to this expense yet.")
                    .font(.footnote)
                    .foregroundColor(FluxoTheme.secondaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FluxoTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let receiptMessage = viewModel.receiptMessage, viewModel.receiptImage != nil {
                Text(receiptMessage)
                    .font(.caption2)
                    .foregroundColor(FluxoTheme.secondaryText)
            }

            if let fallback = viewModel.sensorFallbackMessage {
                Text(fallback)
                    .font(.caption2)
                    .foregroundColor(FluxoTheme.secondaryText)
            }
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
