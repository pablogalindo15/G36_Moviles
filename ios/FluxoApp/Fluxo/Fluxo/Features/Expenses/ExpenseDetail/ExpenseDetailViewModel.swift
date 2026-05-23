import Foundation
import Combine
import UIKit

@MainActor
final class ExpenseDetailViewModel: ObservableObject {
    @Published private(set) var currentExpense: Expense
    @Published private(set) var isDeleting: Bool = false
    @Published private(set) var didDelete: Bool = false
    @Published private(set) var receiptImage: UIImage? = nil
    @Published private(set) var isLoadingReceipt: Bool = false
    @Published private(set) var isUploadingReceipt: Bool = false
    @Published var receiptMessage: String? = nil
    @Published var deleteError: String? = nil
    @Published var receiptError: String? = nil
    @Published var isShowingReceiptPicker: Bool = false
    @Published var pickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @Published var sensorFallbackMessage: String? = nil

    let expensesService: ExpensesApplicationService
    private let receiptService: ReceiptImageService
    private let cameraFacade: CameraFacade

    init(
        expense: Expense,
        expensesService: ExpensesApplicationService,
        receiptService: ReceiptImageService,
        cameraFacade: CameraFacade
    ) {
        self.currentExpense = expense
        self.expensesService = expensesService
        self.receiptService = receiptService
        self.cameraFacade = cameraFacade
    }

    func handleSavedFromEdit(_ updated: Expense) {
        currentExpense = updated
    }

    func delete() async {
        isDeleting = true
        deleteError = nil
        do {
            try await expensesService.deleteExpense(id: currentExpense.id)
            didDelete = true
        } catch {
            if ConnectivitySupport.isConnectivityIssue(error) {
                deleteError = ExpenseEvCMessages.deleteRequiresInternet(fromList: false)
            } else if !error.isCancelledRequest {
                deleteError = error.localizedDescription
            }
        }
        isDeleting = false
    }

    func loadReceiptIfNeeded() async {
        guard !isLoadingReceipt else { return }
        isLoadingReceipt = true
        receiptError = nil

        _ = await receiptService.syncPendingReceiptIfPossible(for: currentExpense)

        do {
            if let result = try await receiptService.loadReceipt(for: currentExpense) {
                receiptImage = result.image
                if result.hasPendingUpload {
                    receiptMessage = ExpenseEvCMessages.receiptSavedLocallyForRetry()
                } else {
                    receiptMessage = nil
                }
            } else {
                receiptImage = nil
                receiptMessage = "No receipt attached to this expense yet."
            }
        } catch let receiptError as ReceiptImageServiceError {
            receiptImage = nil
            switch receiptError {
            case .offlineWithoutCachedImage:
                receiptMessage = receiptError.errorDescription
            default:
                self.receiptError = receiptError.errorDescription
            }
        } catch {
            if !error.isCancelledRequest {
                receiptError = error.localizedDescription
            }
        }

        isLoadingReceipt = false
    }

    func openReceiptCapture() {
        pickerSourceType = cameraFacade.preferredSourceType()
        sensorFallbackMessage = cameraFacade.fallbackHint
        isShowingReceiptPicker = true
    }

    func handlePickedReceipt(_ image: UIImage?) async {
        guard let image else { return }
        isUploadingReceipt = true
        receiptError = nil
        do {
            try await receiptService.uploadReceipt(image, for: currentExpense)
            receiptImage = image
            receiptMessage = nil
        } catch {
            if ConnectivitySupport.isConnectivityIssue(error) {
                await receiptService.queueReceiptForLaterUpload(image, for: currentExpense)
                receiptImage = image
                receiptMessage = ExpenseEvCMessages.receiptSavedLocallyForRetry()
            } else if !error.isCancelledRequest {
                receiptError = error.localizedDescription
            }
        }
        isUploadingReceipt = false
    }
}
