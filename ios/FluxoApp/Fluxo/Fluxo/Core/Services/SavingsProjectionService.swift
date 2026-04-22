import Foundation

enum SavingsProjectionServiceError: Error, LocalizedError {
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

final class SavingsProjectionService {
    private let functionsAdapter: FunctionsAdapter
    private let authAdapter: AuthAdapter

    init(functionsAdapter: FunctionsAdapter, authAdapter: AuthAdapter) {
        self.functionsAdapter = functionsAdapter
        self.authAdapter = authAdapter
    }

    func fetchSavingsProjection(currentDate: Date? = nil) async throws -> SavingsProjectionResult {
        // authAdapter.currentAccessToken() is async throws.
        let token: String
        do {
            token = try await authAdapter.currentAccessToken()
        } catch {
            throw SavingsProjectionServiceError.notAuthenticated
        }

        let data: Data
        do {
            data = try await functionsAdapter.getSavingsProjection(currentDate: currentDate, accessToken: token)
        } catch {
            throw SavingsProjectionServiceError.underlying(error)
        }

        let decoder = JSONDecoder()

        // Schema A: full result.
        if let projection = try? decoder.decode(SavingsProjection.self, from: data) {
            return .ready(projection)
        }

        // Schema B: insufficient data.
        struct InsufficientResponse: Decodable {
            let insufficient_data: Bool
            let expenses_count_basis: Int
            let reason: String?
        }
        if let ins = try? decoder.decode(InsufficientResponse.self, from: data),
           ins.insufficient_data {
            return .insufficientData(expensesCount: ins.expenses_count_basis)
        }

        let err = NSError(
            domain: "SavingsProjectionService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected response schema"]
        )
        throw SavingsProjectionServiceError.decodingFailed(err)
    }
}
