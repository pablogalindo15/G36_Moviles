import Foundation

enum TopCategoriesServiceError: Error, LocalizedError {
    case notAuthenticated
    case decodingFailed(Error)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:     return "Your session expired."
        case .decodingFailed:       return "Couldn't parse the response."
        case .underlying(let e):    return e.localizedDescription
        }
    }
}

final class TopCategoriesService {
    private let functionsAdapter: FunctionsAdapter
    private let authAdapter: AuthAdapter

    init(functionsAdapter: FunctionsAdapter, authAdapter: AuthAdapter) {
        self.functionsAdapter = functionsAdapter
        self.authAdapter = authAdapter
    }

    func fetchTopCategories() async throws -> TopCategoriesResult {
        let data: Data
        do {
            data = try await requestTopCategories()
        } catch {
            throw TopCategoriesServiceError.underlying(error)
        }

        let decoder = JSONDecoder()

        if let payload = try? decoder.decode(TopCategoriesPayload.self, from: data) {
            return .ready(payload)
        }

        struct InsufficientResponse: Decodable {
            let total_expenses: Int
            let reason: String?
        }
        if let ins = try? decoder.decode(InsufficientResponse.self, from: data),
           ins.reason == "insufficient_data" {
            return .insufficientData(totalExpenses: ins.total_expenses)
        }

        let err = NSError(
            domain: "TopCategoriesService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected response schema"]
        )
        throw TopCategoriesServiceError.decodingFailed(err)
    }

    private func requestTopCategories() async throws -> Data {
        guard let token = try? await authAdapter.currentAccessToken() else {
            throw TopCategoriesServiceError.notAuthenticated
        }

        do {
            return try await functionsAdapter.getTopCategories(accessToken: token)
        } catch let error as FunctionsAdapterError {
            guard case .backend(let statusCode, _, _) = error, statusCode == 401 else {
                throw error
            }
            return try await functionsAdapter.getTopCategories(
                accessToken: try await authAdapter.refreshSession()
            )
        }
    }
}
