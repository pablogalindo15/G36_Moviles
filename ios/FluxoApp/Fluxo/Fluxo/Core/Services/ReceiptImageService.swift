import Foundation
import UIKit

enum ReceiptImageSource {
    case memoryCache
    case diskCache
    case remote
}

struct ReceiptImageResult {
    let image: UIImage
    let source: ReceiptImageSource
    let hasPendingUpload: Bool
}

enum ReceiptImageServiceError: Error, LocalizedError {
    case notAuthenticated
    case offlineWithoutCachedImage
    case decodeFailed
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Your session expired. Please sign in again."
        case .offlineWithoutCachedImage:
            return ExpenseEvCMessages.receiptNeedsInternetUntilCached()
        case .decodeFailed:
            return "The receipt image could not be decoded."
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

final class ReceiptImageService {
    private let receiptsAdapter: ReceiptsAdapter
    private let authAdapter: AuthAdapter
    private let imageCache: ImageCacheService
    private let defaults: UserDefaults

    private let pendingUploadsKey = "pref.pendingReceiptUploads"
    private let draftReceiptKey = "draft-expense-receipt"

    init(
        receiptsAdapter: ReceiptsAdapter,
        authAdapter: AuthAdapter,
        imageCache: ImageCacheService,
        defaults: UserDefaults = .standard
    ) {
        self.receiptsAdapter = receiptsAdapter
        self.authAdapter = authAdapter
        self.imageCache = imageCache
        self.defaults = defaults
    }

    func uploadReceipt(_ image: UIImage, for expense: Expense) async throws {
        let data = try jpegData(from: image)
        let cacheKey = cacheKey(for: expense)

        do {
            let token = try await authAdapter.currentAccessToken()
            try await uploadReceipt(
                data: data,
                accessToken: token,
                expense: expense
            )
            await imageCache.store(image, forKey: cacheKey)
            removePendingUpload(for: expense)
        } catch let storageError as ReceiptStorageError where storageError.statusCode == 401 {
            let refreshedToken = try await authAdapter.refreshSession()
            try await uploadReceipt(
                data: data,
                accessToken: refreshedToken,
                expense: expense
            )
            await imageCache.store(image, forKey: cacheKey)
            removePendingUpload(for: expense)
        } catch {
            throw ReceiptImageServiceError.underlying(error)
        }
    }

    func queueReceiptForLaterUpload(_ image: UIImage, for expense: Expense) async {
        await imageCache.store(image, forKey: cacheKey(for: expense))
        addPendingUpload(for: expense)
    }

    func hasPendingReceiptUpload(for expense: Expense) -> Bool {
        pendingUploadKeys().contains(cacheKey(for: expense))
    }

    @discardableResult
    func syncPendingReceiptIfPossible(for expense: Expense) async -> Bool {
        guard hasPendingReceiptUpload(for: expense),
              let cached = await imageCache.cachedImage(forKey: cacheKey(for: expense)) else {
            return false
        }

        do {
            try await uploadReceipt(cached.image, for: expense)
            return true
        } catch {
            return false
        }
    }

    func loadReceipt(for expense: Expense) async throws -> ReceiptImageResult? {
        let key = cacheKey(for: expense)
        let pendingUpload = hasPendingReceiptUpload(for: expense)

        if let cached = await imageCache.cachedImage(forKey: key) {
            if pendingUpload {
                _ = await syncPendingReceiptIfPossible(for: expense)
            }
            return ReceiptImageResult(
                image: cached.image,
                source: cached.source == .memory ? .memoryCache : .diskCache,
                hasPendingUpload: hasPendingReceiptUpload(for: expense)
            )
        }

        let token: String
        do {
            token = try await authAdapter.currentAccessToken()
        } catch {
            throw ReceiptImageServiceError.notAuthenticated
        }

        do {
            if let data = try await receiptsAdapter.downloadReceipt(
                accessToken: token,
                userId: expense.userId,
                expenseId: expense.id
            ) {
                guard let image = UIImage(data: data) else {
                    throw ReceiptImageServiceError.decodeFailed
                }
                await imageCache.store(image, forKey: key)
                return ReceiptImageResult(image: image, source: .remote, hasPendingUpload: false)
            }
            return nil
        } catch let storageError as ReceiptStorageError where storageError.statusCode == 401 {
            let refreshedToken = try await authAdapter.refreshSession()
            if let data = try await receiptsAdapter.downloadReceipt(
                accessToken: refreshedToken,
                userId: expense.userId,
                expenseId: expense.id
            ) {
                guard let image = UIImage(data: data) else {
                    throw ReceiptImageServiceError.decodeFailed
                }
                await imageCache.store(image, forKey: key)
                return ReceiptImageResult(image: image, source: .remote, hasPendingUpload: false)
            }
            return nil
        } catch {
            if ConnectivitySupport.isConnectivityIssue(error) {
                throw ReceiptImageServiceError.offlineWithoutCachedImage
            }
            throw ReceiptImageServiceError.underlying(error)
        }
    }

    func saveDraftReceipt(_ image: UIImage?) async {
        if let image {
            await imageCache.store(image, forKey: draftReceiptKey)
        } else {
            await imageCache.removeImage(forKey: draftReceiptKey)
        }
    }

    func loadDraftReceipt() async -> UIImage? {
        let cached = await imageCache.cachedImage(forKey: draftReceiptKey)
        return cached?.image
    }

    func clearDraftReceipt() async {
        await imageCache.removeImage(forKey: draftReceiptKey)
    }

    private func uploadReceipt(data: Data, accessToken: String, expense: Expense) async throws {
        _ = try await receiptsAdapter.uploadReceipt(
            accessToken: accessToken,
            userId: expense.userId,
            expenseId: expense.id,
            imageData: data
        )
    }

    private func jpegData(from image: UIImage) throws -> Data {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw ReceiptImageServiceError.decodeFailed
        }
        return data
    }

    private func cacheKey(for expense: Expense) -> String {
        ReceiptsAdapter.objectPath(userId: expense.userId, expenseId: expense.id)
    }

    private func addPendingUpload(for expense: Expense) {
        var keys = pendingUploadKeys()
        keys.insert(cacheKey(for: expense))
        savePendingUploadKeys(keys)
    }

    private func removePendingUpload(for expense: Expense) {
        var keys = pendingUploadKeys()
        keys.remove(cacheKey(for: expense))
        savePendingUploadKeys(keys)
    }

    private func pendingUploadKeys() -> Set<String> {
        let values = defaults.array(forKey: pendingUploadsKey) as? [String] ?? []
        return Set(values)
    }

    private func savePendingUploadKeys(_ keys: Set<String>) {
        defaults.set(Array(keys).sorted(), forKey: pendingUploadsKey)
    }
}
