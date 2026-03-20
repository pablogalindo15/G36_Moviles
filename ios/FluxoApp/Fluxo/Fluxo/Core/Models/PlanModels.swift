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
}
