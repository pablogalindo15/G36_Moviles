import { createClient } from "npm:@supabase/supabase-js@2";
import {
  GenerateFirstPlanRequestDto,
  GenerateFirstPlanResponseDto,
  GeneratedPlanDto,
} from "../_shared/contracts.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type ErrorPayload = {
  error: string;
  details?: string;
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function round2(value: number): number {
  return Number(value.toFixed(2));
}

function parseDateOnlyOrIso(value: string): Date | null {
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? null : parsed;
}

function differenceInDays(currentDate: Date, nextPayday: Date): number {
  const msPerDay = 24 * 60 * 60 * 1000;
  const diffMs = nextPayday.getTime() - currentDate.getTime();
  return Math.ceil(diffMs / msPerDay);
}

function parseRequest(body: unknown): GenerateFirstPlanRequestDto | ErrorPayload {
  const input = body as Record<string, unknown>;
  const required = [
    "user_id",
    "current_date",
    "currency",
    "monthly_income",
    "fixed_monthly_expenses",
    "monthly_savings_goal",
    "next_payday",
  ] as const;

  for (const key of required) {
    const value = input[key];
    if (value === undefined || value === null || value === "") {
      return { error: `Missing required field: ${key}` };
    }
  }

  const monthly_income = Number(input.monthly_income);
  const fixed_monthly_expenses = Number(input.fixed_monthly_expenses);
  const monthly_savings_goal = Number(input.monthly_savings_goal);

  if (
    !Number.isFinite(monthly_income) ||
    !Number.isFinite(fixed_monthly_expenses) ||
    !Number.isFinite(monthly_savings_goal)
  ) {
    return {
      error:
        "monthly_income, fixed_monthly_expenses and monthly_savings_goal must be numeric values",
    };
  }

  const user_id = String(input.user_id).trim();
  const currency = String(input.currency).trim();
  const current_date = String(input.current_date).trim();
  const next_payday = String(input.next_payday).trim();

  if (!user_id || !currency || !current_date || !next_payday) {
    return { error: "user_id, currency, current_date and next_payday must be non-empty strings" };
  }

  const currentDateParsed = parseDateOnlyOrIso(current_date);
  const nextPaydayParsed = parseDateOnlyOrIso(next_payday);
  if (!currentDateParsed || !nextPaydayParsed) {
    return { error: "current_date and next_payday must be valid dates" };
  }

  return {
    user_id,
    current_date,
    currency,
    monthly_income,
    fixed_monthly_expenses,
    monthly_savings_goal,
    next_payday,
  };
}

function getInsightMessage(daysUntilPayday: number): string {
  if (daysUntilPayday <= 7) {
    return "Your next payday is close, so your plan has been tightened for the remaining days of this cycle.";
  }
  if (daysUntilPayday <= 15) {
    return "Your plan has been adjusted to help you stay balanced until your next payday.";
  }
  return "You still have time in this cycle, so this plan spreads your available budget more evenly.";
}

function getBearerToken(req: Request): string | null {
  const auth = req.headers.get("authorization");
  if (!auth) return null;
  return auth.toLowerCase().startsWith("bearer ") ? auth.slice(7) : auth;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  let body: unknown;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Body must be valid JSON" }, 400);
  }

  const parsed = parseRequest(body);
  if ("error" in parsed) {
    return json(parsed, 400);
  }

  const accessToken = getBearerToken(req);
  if (!accessToken) {
    return json({ error: "Missing Authorization Bearer token" }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    return json(
      {
        error: "Missing required environment variables",
        details: "SUPABASE_URL and SUPABASE_ANON_KEY are required",
      } satisfies ErrorPayload,
      500,
    );
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  });

  const { data: authData, error: authError } = await supabase.auth.getUser(accessToken);
  if (authError || !authData.user) {
    return json({ error: "Invalid or expired access token", details: authError?.message }, 401);
  }

  if (authData.user.id !== parsed.user_id) {
    return json({ error: "user_id does not match authenticated user" }, 403);
  }

  const currentDate = parseDateOnlyOrIso(parsed.current_date)!;
  const nextPayday = parseDateOnlyOrIso(parsed.next_payday)!;

  const days_until_payday = Math.max(1, differenceInDays(currentDate, nextPayday));
  const available_after_fixed_and_savings =
    parsed.monthly_income - parsed.fixed_monthly_expenses - parsed.monthly_savings_goal;
  const discretionary_monthly = Math.max(0, available_after_fixed_and_savings);
  const daily_budget = discretionary_monthly / 30;
  const safe_to_spend_until_next_payday = round2(daily_budget * Math.min(days_until_payday, 30));
  const weeks_remaining = Math.max(1, Math.ceil(days_until_payday / 7));
  const weekly_cap = round2(safe_to_spend_until_next_payday / weeks_remaining);
  const target_savings = round2(Math.max(0, parsed.monthly_savings_goal));
  const contextual_insight_message = getInsightMessage(days_until_payday);

  const { data: setupRow, error: setupError } = await supabase
    .from("financial_setups")
    .insert({
      user_id: parsed.user_id,
      currency: parsed.currency,
      monthly_income: parsed.monthly_income,
      fixed_monthly_expenses: parsed.fixed_monthly_expenses,
      monthly_savings_goal: parsed.monthly_savings_goal,
      next_payday: parsed.next_payday,
    })
    .select("id")
    .single();

  if (setupError) {
    return json({ error: "Failed to insert financial setup", details: setupError.message }, 500);
  }

  const { data: planRow, error: planError } = await supabase
    .from("generated_plans")
    .insert({
      user_id: parsed.user_id,
      financial_setup_id: setupRow.id,
      safe_to_spend_until_next_payday,
      weekly_cap,
      target_savings,
      contextual_insight_message,
    })
    .select("*")
    .single();

  if (planError) {
    return json({ error: "Failed to insert generated plan", details: planError.message }, 500);
  }

  const response: GenerateFirstPlanResponseDto = {
    plan: planRow as GeneratedPlanDto,
  };

  return json(response, 200);
});
