import Foundation

enum ComparativeSpendingServiceError: Error, LocalizedError {
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

final class ComparativeSpendingService {
    private let functionsAdapter: FunctionsAdapter
    private let authAdapter: AuthAdapter

    init(functionsAdapter: FunctionsAdapter, authAdapter: AuthAdapter) {
        self.functionsAdapter = functionsAdapter
        self.authAdapter = authAdapter
    }

    func fetchComparativeSpending(weekEnd: Date? = nil) async throws -> ComparativeSpendingResult {
        // 1. Obtain access token — authAdapter.currentAccessToken() is async throws.
        let token: String
        do {
            token = try await authAdapter.currentAccessToken()
        } catch {
            throw ComparativeSpendingServiceError.notAuthenticated
        }

        // 2. Call the edge function; adapter returns raw Data (polymorphic response).
        let data: Data
        do {
            data = try await functionsAdapter.getComparativeSpending(weekEnd: weekEnd, accessToken: token)
        } catch {
            throw ComparativeSpendingServiceError.underlying(error)
        }

        // 3. Try Schema A: full result (cohort large enough).
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let ready = try? decoder.decode(ComparativeSpending.self, from: data) {
            return .ready(ready)
        }

        // 5. Try Schema B: cohort_too_small.
        struct TooSmallResponse: Decodable {
            let cohort_size: Int
            let reason: String?
        }

        if let tooSmall = try? decoder.decode(TooSmallResponse.self, from: data),
           tooSmall.reason == "cohort_too_small" {
            return .cohortTooSmall(cohortSize: tooSmall.cohort_size)
        }

        // 6. Neither schema matched.
        let parseError = NSError(
            domain: "ComparativeSpendingService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected response schema"]
        )
        throw ComparativeSpendingServiceError.decodingFailed(parseError)
    }
}
