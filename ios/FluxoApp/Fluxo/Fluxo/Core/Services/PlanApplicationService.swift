import Foundation

final class PlanApplicationService {
    private let authAdapter: AuthAdapter
    private let planAdapter: PlanAdapter
    private let functionsAdapter: FunctionsAdapter
    private let localStore: LocalStore

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(
        authAdapter: AuthAdapter,
        planAdapter: PlanAdapter,
        functionsAdapter: FunctionsAdapter,
        localStore: LocalStore
    ) {
        self.authAdapter = authAdapter
        self.planAdapter = planAdapter
        self.functionsAdapter = functionsAdapter
        self.localStore = localStore
    }

    /// Fetches the latest snapshot using the authenticated user's ID from the session.
    /// Used by DashboardViewModel which doesn't receive a userId from outside.
    func fetchLatestSnapshot() async throws -> PlanSnapshot {
        let token = try await authAdapter.currentAccessToken()
        let userId = try authAdapter.currentUserId().uuidString

        do {
            async let setup = planAdapter.fetchLatestFinancialSetup(accessToken: token, userId: userId)
            async let plan = planAdapter.fetchLatestGeneratedPlan(accessToken: token, userId: userId)
            let snapshot = try await PlanSnapshot(setup: setup, plan: plan)
            if let plan = snapshot.plan {
                await MainActor.run { localStore.savePlan(plan) }
            }
            return snapshot
        } catch {
            // Network failed — fall back to cached local plan (no setup available offline).
            let localPlan = await MainActor.run { localStore.fetchLatestPlan(userId: userId) }
            if let localPlan {
                return PlanSnapshot(setup: nil, plan: localPlan)
            }
            throw error
        }
    }

    func loadLatestSnapshot(userId: String) async throws -> PlanSnapshot {
        let token = try await authAdapter.currentAccessToken()

        do {
            async let setup = planAdapter.fetchLatestFinancialSetup(accessToken: token, userId: userId)
            async let plan = planAdapter.fetchLatestGeneratedPlan(accessToken: token, userId: userId)
            let snapshot = try await PlanSnapshot(setup: setup, plan: plan)
            if let plan = snapshot.plan {
                await MainActor.run { localStore.savePlan(plan) }
            }
            return snapshot
        } catch {
            let localPlan = await MainActor.run { localStore.fetchLatestPlan(userId: userId) }
            if let localPlan {
                return PlanSnapshot(setup: nil, plan: localPlan)
            }
            throw error
        }
    }

    func generateFirstPlan(
        userId: String,
        setup: SaveFinancialSetupDTO
    ) async throws -> GeneratedPlanDTO {
        // Build exact payload expected by Supabase Edge Function.
        let request = GenerateFirstPlanRequestDTO(
            user_id: userId,
            current_date: dateFormatter.string(from: Date()),
            currency: setup.currency,
            monthly_income: setup.monthly_income,
            fixed_monthly_expenses: setup.fixed_monthly_expenses,
            monthly_savings_goal: setup.monthly_savings_goal,
            next_payday: setup.next_payday
        )

        var token = try await authAdapter.currentAccessToken()
        do {
            let response = try await functionsAdapter.generateFirstPlan(
                request: request,
                accessToken: token
            )
            await MainActor.run { localStore.savePlan(response.plan) }
            return response.plan
        } catch let error as FunctionsAdapterError {
            switch error {
            case .backend(let statusCode, _, _) where statusCode == 401:
                // If JWT expired, refresh once and retry.
                token = try await authAdapter.refreshSession()
                let retriedResponse = try await functionsAdapter.generateFirstPlan(
                    request: request,
                    accessToken: token
                )
                await MainActor.run { localStore.savePlan(retriedResponse.plan) }
                return retriedResponse.plan
            default:
                throw error
            }
        }
    }
}
