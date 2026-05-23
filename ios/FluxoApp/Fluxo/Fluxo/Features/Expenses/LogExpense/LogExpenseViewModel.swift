import Foundation
import Combine
import UIKit

enum LogExpenseSubmitState: Equatable {
    case idle
    case submitting
    case success(Expense)
    case failure(String)
}

@MainActor
final class LogExpenseViewModel: ObservableObject {
    @Published var amountText: String = ""
    @Published var selectedCategory: ExpenseCategory = .food
    @Published var note: String = ""
    @Published var occurredAt: Date = Date()
    @Published var submitState: LogExpenseSubmitState = .idle
    @Published var infoMessage: String? = nil
    @Published var selectedReceiptImage: UIImage? = nil
    @Published var isShowingReceiptPicker: Bool = false
    @Published var pickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @Published var sensorFallbackMessage: String? = nil

    let currency: String
    private let service: ExpensesApplicationService
    private let receiptService: ReceiptImageService
    private let cameraFacade: CameraFacade
    private let preferencesAdapter: PreferencesAdapter
    private let onExpenseCreated: (Expense, String?) -> Void

    init(
        currency: String,
        service: ExpensesApplicationService,
        receiptService: ReceiptImageService,
        cameraFacade: CameraFacade,
        preferencesAdapter: PreferencesAdapter,
        onExpenseCreated: @escaping (Expense, String?) -> Void
    ) {
        self.currency = currency
        self.service = service
        self.receiptService = receiptService
        self.cameraFacade = cameraFacade
        self.preferencesAdapter = preferencesAdapter
        self.onExpenseCreated = onExpenseCreated
        restoreDraftIfNeeded()
    }

    var isSubmitEnabled: Bool {
        guard !amountText.isEmpty,
              let value = Decimal(string: amountText, locale: .current),
              value > 0
        else { return false }
        return submitState != .submitting
    }

    func submit() async {
        submitState = .submitting
        infoMessage = nil

        guard let amount = Decimal(string: amountText, locale: .current) else {
            submitState = .failure("Invalid amount")
            return
        }

        do {
            let expense = try await service.createExpense(
                amount: amount,
                currency: currency,
                category: selectedCategory,
                note: note.isEmpty ? nil : note,
                occurredAt: occurredAt
            )
            var receiptNotice: String?
            if let selectedReceiptImage {
                do {
                    try await receiptService.uploadReceipt(selectedReceiptImage, for: expense)
                } catch {
                    if ConnectivitySupport.isConnectivityIssue(error) {
                        await receiptService.queueReceiptForLaterUpload(selectedReceiptImage, for: expense)
                        receiptNotice = ExpenseEvCMessages.receiptSavedLocallyForRetry()
                    } else {
                        receiptNotice = "The expense was saved, but the receipt couldn't be uploaded. You can retry from expense detail."
                    }
                }
            }
            preferencesAdapter.setLastSeenCurrency(currency)
            preferencesAdapter.clearExpenseDraft()
            await receiptService.clearDraftReceipt()
            submitState = .success(expense)
            onExpenseCreated(expense, receiptNotice)
        } catch let svcErr as ExpensesServiceError {
            let message: String
            switch svcErr {
            case .invalidAmount:       message = "Amount must be greater than zero"
            case .invalidCurrency:     message = "Invalid currency"
            case .noteTooLong:         message = "Note is too long (max 120 characters)"
            case .futureDate:          message = "Date cannot be in the future"
            case .tooOldDate:          message = "Date too old (max 7 days ago)"
            case .notAuthenticated:    message = "Your session expired, please sign in again"
            case .duplicateExpense:    message = "This expense was already registered"
            case .underlying(let e):
                if ConnectivitySupport.isConnectivityIssue(e) {
                    persistDraft()
                    message = ConnectivitySupport.draftPreservedMessage(for: "save this expense")
                } else {
                    message = e.localizedDescription
                }
            }
            submitState = .failure(message)
        } catch {
            if ConnectivitySupport.isConnectivityIssue(error) {
                persistDraft()
                submitState = .failure(ConnectivitySupport.draftPreservedMessage(for: "save this expense"))
            } else {
                submitState = .failure("Something went wrong. Please try again.")
            }
        }
    }

    func persistDraft() {
        let draft = ExpenseDraft(
            amountText: amountText,
            selectedCategoryRaw: selectedCategory.rawValue,
            note: note,
            occurredAtTimeInterval: occurredAt.timeIntervalSince1970,
            hasReceiptDraft: selectedReceiptImage != nil
        )
        preferencesAdapter.setExpenseDraft(draft)
        let receipt = selectedReceiptImage
        Task {
            await receiptService.saveDraftReceipt(receipt)
        }
    }

    func reset() {
        amountText = ""
        selectedCategory = .food
        note = ""
        occurredAt = Date()
        submitState = .idle
        infoMessage = nil
        selectedReceiptImage = nil
        sensorFallbackMessage = nil
        preferencesAdapter.clearExpenseDraft()
        Task { await receiptService.clearDraftReceipt() }
    }

    func openReceiptCapture() {
        pickerSourceType = cameraFacade.preferredSourceType()
        sensorFallbackMessage = cameraFacade.fallbackHint
        isShowingReceiptPicker = true
    }

    func savePickedReceipt(_ image: UIImage?) {
        selectedReceiptImage = image
        persistDraft()
    }

    private func restoreDraftIfNeeded() {
        guard let draft = preferencesAdapter.getExpenseDraft() else { return }
        amountText = draft.amountText
        selectedCategory = draft.selectedCategory
        note = draft.note
        occurredAt = draft.occurredAt
        let baseMessage = "Recovered your saved expense draft. Review it and try again."
        if draft.hasReceiptDraft == true {
            infoMessage = "\(baseMessage) The receipt preview was also restored on this device."
            Task { @MainActor [weak self] in
                guard let self else { return }
                selectedReceiptImage = await receiptService.loadDraftReceipt()
            }
        } else {
            infoMessage = baseMessage
        }
    }
}
