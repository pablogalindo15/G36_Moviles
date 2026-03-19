/**
 * DTO / TO contracts for Fluxo backend integration.
 * Kept minimal for easy viva voce explanation.
 */

export interface SignUpDto {
  email: string;
  password: string;
  full_name: string;
}

export interface SignInDto {
  email: string;
  password: string;
}

export interface SaveProfileDto {
  full_name: string;
  avatar_url: string | null;
}

export interface SaveFinancialSetupDto {
  currency: string;
  monthly_income: number;
  fixed_monthly_expenses: number;
  monthly_savings_goal: number;
  next_payday: string;
}

export interface GenerateFirstPlanRequestDto extends SaveFinancialSetupDto {
  user_id: string;
  current_date: string;
}

export interface GeneratedPlanDto {
  id: string;
  user_id: string;
  financial_setup_id: string;
  safe_to_spend_until_next_payday: number;
  weekly_cap: number;
  target_savings: number;
  contextual_insight_message: string;
  generated_at: string;
}

export interface GenerateFirstPlanResponseDto {
  plan: GeneratedPlanDto;
}
