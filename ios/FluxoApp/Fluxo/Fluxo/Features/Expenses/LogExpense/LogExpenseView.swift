import SwiftUI

struct LogExpenseView: View {
    @StateObject private var viewModel: LogExpenseViewModel
    @Environment(\.dismiss) private var dismiss

    init(
        currency: String,
        service: ExpensesApplicationService,
        receiptService: ReceiptImageService,
        cameraFacade: CameraFacade,
        preferencesAdapter: PreferencesAdapter,
        onExpenseCreated: @escaping (Expense, String?) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: LogExpenseViewModel(
                currency: currency,
                service: service,
                receiptService: receiptService,
                cameraFacade: cameraFacade,
                preferencesAdapter: preferencesAdapter,
                onExpenseCreated: onExpenseCreated
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    amountSection
                    categorySection
                    noteSection
                    receiptSection
                    dateSection

                    if case .failure(let msg) = viewModel.submitState {
                        Text(msg)
                            .font(.footnote)
                            .foregroundColor(FluxoTheme.error)
                            .multilineTextAlignment(.center)
                    }

                    if let infoMessage = viewModel.infoMessage {
                        Text(infoMessage)
                            .font(.footnote)
                            .foregroundColor(FluxoTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task { await viewModel.submit() }
                    } label: {
                        Text("Save expense")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FluxoPrimaryButtonStyle(isDisabled: !viewModel.isSubmitEnabled))
                    .disabled(!viewModel.isSubmitEnabled)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
            }
            .background(FluxoTheme.background.ignoresSafeArea())
            .navigationTitle("Log expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $viewModel.isShowingReceiptPicker) {
                SystemImagePicker(sourceType: viewModel.pickerSourceType) { image in
                    viewModel.savePickedReceipt(image)
                }
            }
            .overlay {
                if viewModel.submitState == .submitting {
                    LoadingOverlay(title: "Saving...")
                }
            }
            .onChange(of: viewModel.amountText) { _, _ in
                viewModel.persistDraft()
            }
            .onChange(of: viewModel.selectedCategory) { _, _ in
                viewModel.persistDraft()
            }
            .onChange(of: viewModel.note) { _, _ in
                viewModel.persistDraft()
            }
            .onChange(of: viewModel.occurredAt) { _, _ in
                viewModel.persistDraft()
            }
            .onChange(of: viewModel.selectedReceiptImage) { _, _ in
                viewModel.persistDraft()
            }
            .onChange(of: viewModel.submitState) { _, newValue in
                if case .success = newValue {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections

    private var amountSection: some View {
        VStack(spacing: 8) {
            Text("Amount")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            HStack(spacing: 4) {
                Text(viewModel.currency)
                    .font(.title2)
                    .foregroundColor(FluxoTheme.secondaryText)
                TextField("0.00", text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundColor(FluxoTheme.titleText)
            }
        }
        .padding(.top, 16)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: viewModel.selectedCategory == category,
                            onTap: { viewModel.selectedCategory = category }
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    private var noteSection: some View {
        FluxoInputField(title: "Note (optional)") {
            TextField("What was it for?", text: $viewModel.note)
                .autocorrectionDisabled()
        }
    }

    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Receipt (optional)")
                    .font(.caption)
                    .foregroundColor(FluxoTheme.secondaryText)
                Spacer()
                Button(viewModel.selectedReceiptImage == nil ? "Add receipt" : "Replace receipt") {
                    viewModel.openReceiptCapture()
                }
                .font(.footnote.weight(.semibold))
                .foregroundColor(FluxoTheme.primary)
            }

            if let selectedReceiptImage = viewModel.selectedReceiptImage {
                Image(uiImage: selectedReceiptImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 180)
                    .background(FluxoTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("Attach a receipt photo so it can be viewed later from expense detail.")
                    .font(.footnote)
                    .foregroundColor(FluxoTheme.secondaryText)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FluxoTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let fallback = viewModel.sensorFallbackMessage {
                Text(fallback)
                    .font(.caption2)
                    .foregroundColor(FluxoTheme.secondaryText)
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(.caption)
                .foregroundColor(FluxoTheme.secondaryText)
            DatePicker(
                "",
                selection: $viewModel.occurredAt,
                in: Date().addingTimeInterval(-7 * 24 * 3600)...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                Text(category.displayName)
                    .font(.subheadline)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(isSelected ? FluxoTheme.primary : Color.clear)
            .foregroundColor(isSelected ? .white : FluxoTheme.titleText)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        isSelected ? FluxoTheme.primary : FluxoTheme.secondaryText.opacity(0.3),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
