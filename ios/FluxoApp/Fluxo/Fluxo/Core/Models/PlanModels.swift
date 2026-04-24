import Foundation

struct SaveFinancialSetupDTO: Codable {
    let currency: String
    let monthly_income: Double
    let fixed_monthly_expenses: Double
    let monthly_savings_goal: Double
    let next_payday: String
}

struct GenerateFirstPlanRequestDTO: Codable {
    let user_id: String
    let current_date: String
    let currency: String
    let monthly_income: Double
    let fixed_monthly_expenses: Double
    let monthly_savings_goal: Double
    let next_payday: String
}

struct GeneratedPlanDTO: Codable, Equatable, Identifiable {
    let id: String
    let user_id: String
    let financial_setup_id: String
    let safe_to_spend_until_next_payday: Double
    let weekly_cap: Double
    let target_savings: Double
    let contextual_insight_message: String
    let generated_at: String
}

struct GenerateFirstPlanResponseDTO: Codable {
    let plan: GeneratedPlanDTO
}

struct FinancialSetupRow: Codable {
    let id: String
    let user_id: String
    let currency: String
    let monthly_income: Double
    let fixed_monthly_expenses: Double
    let monthly_savings_goal: Double
    let next_payday: String
    let created_at: String?
    let updated_at: String?
}

struct PlanSnapshot {
    let setup: FinancialSetupRow?
    let plan: GeneratedPlanDTO?
    let source: PlanSnapshotSource
    let fallbackReason: PlanSnapshotFallbackReason?

    init(
        setup: FinancialSetupRow?,
        plan: GeneratedPlanDTO?,
        source: PlanSnapshotSource = .network,
        fallbackReason: PlanSnapshotFallbackReason? = nil
    ) {
        self.setup = setup
        self.plan = plan
        self.source = source
        self.fallbackReason = fallbackReason
    }
}

enum PlanSnapshotSource {
    case network
    case memoryCache
    case localCache
}

enum PlanSnapshotFallbackReason {
    case connectivity
    case refreshFailed
}

extension PlanSnapshot {
    func withSource(_ source: PlanSnapshotSource) -> PlanSnapshot {
        PlanSnapshot(
            setup: setup,
            plan: plan,
            source: source,
            fallbackReason: fallbackReason
        )
    }

    func withFallbackReason(_ fallbackReason: PlanSnapshotFallbackReason?) -> PlanSnapshot {
        PlanSnapshot(
            setup: setup,
            plan: plan,
            source: source,
            fallbackReason: fallbackReason
        )
    }
}

extension FinancialSetupRow {
    static func localRow(
        id: String,
        userId: String,
        dto: SaveFinancialSetupDTO,
        now: Date = Date()
    ) -> FinancialSetupRow {
        let timestamp = Self.iso8601.string(from: now)
        return FinancialSetupRow(
            id: id,
            user_id: userId.lowercased(),
            currency: dto.currency,
            monthly_income: dto.monthly_income,
            fixed_monthly_expenses: dto.fixed_monthly_expenses,
            monthly_savings_goal: dto.monthly_savings_goal,
            next_payday: dto.next_payday,
            created_at: timestamp,
            updated_at: timestamp
        )
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
