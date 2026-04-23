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
        let data: Data
        do {
            data = try await requestComparativeSpending(weekEnd: weekEnd)
        } catch {
            throw ComparativeSpendingServiceError.underlying(error)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let ready = try? decoder.decode(ComparativeSpending.self, from: data) {
            return .ready(ready)
        }

        struct TooSmallResponse: Decodable {
            let cohort_size: Int
            let reason: String?
        }

        if let tooSmall = try? decoder.decode(TooSmallResponse.self, from: data),
           tooSmall.reason == "cohort_too_small" {
            return .cohortTooSmall(cohortSize: tooSmall.cohort_size)
        }

        let parseError = NSError(
            domain: "ComparativeSpendingService",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Unexpected response schema"]
        )
        throw ComparativeSpendingServiceError.decodingFailed(parseError)
    }

    private func requestComparativeSpending(weekEnd: Date?) async throws -> Data {
        let token: String
        do {
            token = try await authAdapter.currentAccessToken()
        } catch {
            throw ComparativeSpendingServiceError.notAuthenticated
        }

        do {
            return try await functionsAdapter.getComparativeSpending(
                weekEnd: weekEnd,
                accessToken: token
            )
        } catch let error as FunctionsAdapterError {
            guard case .backend(let statusCode, _, _) = error, statusCode == 401 else {
                throw error
            }
            return try await functionsAdapter.getComparativeSpending(
                weekEnd: weekEnd,
                accessToken: try await authAdapter.refreshSession()
            )
        }
    }
}
