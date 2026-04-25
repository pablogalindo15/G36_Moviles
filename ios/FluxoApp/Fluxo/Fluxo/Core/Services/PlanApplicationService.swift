import Foundation

final class PlanApplicationService {
    private let authAdapter: AuthAdapter
    private let planAdapter: PlanAdapter
    private let functionsAdapter: FunctionsAdapter
    private let localStore: LocalStore
    private let snapshotCache: PlanSnapshotMemoryCache

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
        localStore: LocalStore,
        snapshotCache: PlanSnapshotMemoryCache
    ) {
        self.authAdapter = authAdapter
        self.planAdapter = planAdapter
        self.functionsAdapter = functionsAdapter
        self.localStore = localStore
        self.snapshotCache = snapshotCache
    }

    func fetchLatestSnapshot(forceRefresh: Bool = false) async throws -> PlanSnapshot {
        return try await loadLatestSnapshot(
            userId: authAdapter.currentUserId().uuidString.lowercased(),
            forceRefresh: forceRefresh
        )
    }

    func loadLatestSnapshot(userId: String, forceRefresh: Bool = false) async throws -> PlanSnapshot {
        let normalizedUserId = userId.lowercased()

        if !forceRefresh, let cached = snapshotCache.snapshot(for: normalizedUserId) {
            return cached.withSource(.memoryCache)
        }

        do {
            let snapshot = try await fetchRemoteSnapshotWithSessionRecovery(userId: normalizedUserId)
            await saveSnapshot(snapshot, for: normalizedUserId)
            return snapshot
        } catch {
            if let snapshot = await localSnapshot(userId: normalizedUserId) {
                let fallbackReason: PlanSnapshotFallbackReason =
                    ConnectivitySupport.isConfirmedOfflineIssue(error) ? .connectivity : .refreshFailed
                return snapshot.withFallbackReason(fallbackReason)
            }
            throw error
        }
    }

    func generateFirstPlan(
        userId: String,
        setup: SaveFinancialSetupDTO
    ) async throws -> GeneratedPlanDTO {
        let request = GenerateFirstPlanRequestDTO(
            user_id: userId,
            current_date: dateFormatter.string(from: Date()),
            currency: setup.currency,
            monthly_income: setup.monthly_income,
            fixed_monthly_expenses: setup.fixed_monthly_expenses,
            monthly_savings_goal: setup.monthly_savings_goal,
            next_payday: setup.next_payday
        )

        do {
            let response = try await functionsAdapter.generateFirstPlan(
                request: request,
                accessToken: try await authAdapter.currentAccessToken()
            )
            await saveGeneratedPlan(response.plan, userId: userId, setup: setup)
            return response.plan
        } catch let error as FunctionsAdapterError {
            switch error {
            case .backend(let statusCode, _, _) where statusCode == 401:
                let retriedResponse = try await functionsAdapter.generateFirstPlan(
                    request: request,
                    accessToken: try await authAdapter.refreshSession()
                )
                await saveGeneratedPlan(retriedResponse.plan, userId: userId, setup: setup)
                return retriedResponse.plan
            default:
                throw error
            }
        }
    }

    private func fetchRemoteSnapshot(userId: String, accessToken: String) async throws -> PlanSnapshot {
        async let setup = planAdapter.fetchLatestFinancialSetup(accessToken: accessToken, userId: userId)
        async let plan = planAdapter.fetchLatestGeneratedPlan(accessToken: accessToken, userId: userId)
        return try await PlanSnapshot(setup: setup, plan: plan)
    }

    private func fetchRemoteSnapshotWithSessionRecovery(userId: String) async throws -> PlanSnapshot {
        do {
            return try await fetchRemoteSnapshot(
                userId: userId,
                accessToken: try await authAdapter.currentAccessToken()
            )
        } catch let error as PostgrestAdapterError {
            guard case .backend(let statusCode, _) = error, statusCode == 401 else {
                throw error
            }
            return try await fetchRemoteSnapshot(
                userId: userId,
                accessToken: try await authAdapter.refreshSession()
            )
        }
    }

    private func localSnapshot(userId: String) async -> PlanSnapshot? {
        let setup = await MainActor.run { localStore.fetchLatestSetup(userId: userId) }
        let plan = await MainActor.run { localStore.fetchLatestPlan(userId: userId) }
        guard setup != nil || plan != nil else { return nil }
        return PlanSnapshot(setup: setup, plan: plan, source: .localCache)
    }

    private func saveGeneratedPlan(
        _ plan: GeneratedPlanDTO,
        userId: String,
        setup: SaveFinancialSetupDTO
    ) async {
        let localSetup = FinancialSetupRow.localRow(
            id: plan.financial_setup_id,
            userId: userId,
            dto: setup
        )
        await saveSnapshot(
            PlanSnapshot(setup: localSetup, plan: plan),
            for: userId.lowercased()
        )
    }

    private func saveSnapshot(_ snapshot: PlanSnapshot, for userId: String) async {
        await MainActor.run {
            if let setup = snapshot.setup {
                localStore.saveSetup(setup)
            }
            if let plan = snapshot.plan {
                localStore.savePlan(plan)
            }
        }
        snapshotCache.store(snapshot, for: userId)
    }
}
