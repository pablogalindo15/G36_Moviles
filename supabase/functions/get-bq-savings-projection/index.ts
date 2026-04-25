import { createClient } from "npm:@supabase/supabase-js@2";

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

  // -----------------------------------------------------------------
  // 1. Auth
  // -----------------------------------------------------------------
  const accessToken = getBearerToken(req);
  if (!accessToken) {
    return json({ error: "Missing authorization header" }, 401);
  }

  // -----------------------------------------------------------------
  // 2. Parse body — current_date is optional (defaults to now)
  // -----------------------------------------------------------------
  let body: { current_date?: unknown } = {};
  try {
    body = await req.json();
  } catch {
    // Empty or missing body is fine — we use defaults below.
  }

  const currentDate = body.current_date ? new Date(body.current_date as string) : new Date();

  // -----------------------------------------------------------------
  // 3. Environment variables
  // -----------------------------------------------------------------
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

  // -----------------------------------------------------------------
  // 4. Single Supabase client with user JWT (RLS enforced — personal data only)
  // -----------------------------------------------------------------
  const supabaseUserClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  });

  try {
    // -----------------------------------------------------------------
    // 5. Validate JWT + resolve current user
    // -----------------------------------------------------------------
    const { data: userData, error: userError } = await supabaseUserClient.auth.getUser(
      accessToken,
    );
    if (userError || !userData.user) {
      return json({ error: "Invalid token", details: userError?.message }, 401);
    }
    const userId = userData.user.id;
    console.log(`[bq-savings-projection] request user=${userId} currentDate=${currentDate.toISOString()}`);

    // -----------------------------------------------------------------
    // 6. Read the user's most recent financial setup
    // -----------------------------------------------------------------
    const { data: setupRows, error: setupError } = await supabaseUserClient
      .from("financial_setups")
      .select("monthly_income, fixed_monthly_expenses, monthly_savings_goal, next_payday, currency")
      .eq("user_id", userId)
      .order("created_at", { ascending: false })
      .limit(1);

    if (setupError) {
      return json(
        { error: "Failed to read financial setup", details: setupError.message } satisfies ErrorPayload,
        500,
      );
    }
    if (!setupRows || setupRows.length === 0) {
      return json({ error: "No financial setup found" }, 404);
    }

    const setup = setupRows[0];
    // Postgres NUMERIC/DECIMAL columns arrive as strings in JS — always convert with Number().
    const monthlyIncome = Number(setup.monthly_income);
    const fixedMonthlyExpenses = Number(setup.fixed_monthly_expenses);
    const monthlySavingsGoal = Number(setup.monthly_savings_goal);
    const currency = String(setup.currency).toUpperCase();

    // -----------------------------------------------------------------
    // 7. Calculate dates
    // -----------------------------------------------------------------
    const nextPaydayDate = new Date(setup.next_payday); // "YYYY-MM-DD" UTC string

    // Sprint 3 approximation: last_payday = next_payday - 1 month. Assumes monthly cycle.
    const lastPaydayDate = new Date(nextPaydayDate);
    lastPaydayDate.setMonth(lastPaydayDate.getMonth() - 1);

    const twoWeeksAgo = new Date(currentDate.getTime() - 14 * 24 * 60 * 60 * 1000);

    const cycleDaysRemaining = Math.floor(
      (nextPaydayDate.getTime() - currentDate.getTime()) / (1000 * 60 * 60 * 24),
    );

    if (cycleDaysRemaining <= 0) {
      return json({ error: "Cycle already ended, regenerate plan" }, 400);
    }

    console.log(
      `[bq-savings-projection] nextPayday=${nextPaydayDate.toISOString()} cycleDaysRemaining=${cycleDaysRemaining}`,
    );

    // -----------------------------------------------------------------
    // 8. Fetch expenses of the last 2 weeks to derive weekly spending rate
    // -----------------------------------------------------------------
    const { data: recentExpenseRows, error: recentExpensesError } = await supabaseUserClient
      .from("expenses")
      .select("amount")
      .eq("user_id", userId)
      .eq("currency", currency)
      .gte("occurred_at", twoWeeksAgo.toISOString())
      .lte("occurred_at", currentDate.toISOString());

    if (recentExpensesError) {
      return json(
        { error: "Failed to read recent expenses", details: recentExpensesError.message } satisfies ErrorPayload,
        500,
      );
    }

    const expensesCountBasis = (recentExpenseRows ?? []).length;
    console.log(`[bq-savings-projection] expensesCountBasis=${expensesCountBasis}`);

    // -----------------------------------------------------------------
    // 9. Insufficient data guard
    // -----------------------------------------------------------------
    if (expensesCountBasis < 3) {
      return json({
        insufficient_data: true,
        expenses_count_basis: expensesCountBasis,
        reason: "need_more_expenses",
      });
    }

    // -----------------------------------------------------------------
    // 10. Fetch expenses of the current cycle (last_payday → current_date)
    // -----------------------------------------------------------------
    const { data: cycleExpenseRows, error: cycleExpensesError } = await supabaseUserClient
      .from("expenses")
      .select("amount")
      .eq("user_id", userId)
      .eq("currency", currency)
      .gte("occurred_at", lastPaydayDate.toISOString())
      .lte("occurred_at", currentDate.toISOString());

    if (cycleExpensesError) {
      return json(
        { error: "Failed to read cycle expenses", details: cycleExpensesError.message } satisfies ErrorPayload,
        500,
      );
    }

    // -----------------------------------------------------------------
    // 11. Calculations
    // -----------------------------------------------------------------
    const spentLast2Weeks = (recentExpenseRows ?? []).reduce(
      (sum, row) => sum + Number(row.amount),
      0,
    );
    const spentInCycleSoFar = (cycleExpenseRows ?? []).reduce(
      (sum, row) => sum + Number(row.amount),
      0,
    );

    const weeklySpendingRate = spentLast2Weeks / 2;
    const weeksRemaining = cycleDaysRemaining / 7;
    const projectedRemainingSpend = weeklySpendingRate * weeksRemaining;
    const projectedTotalSpend = spentInCycleSoFar + projectedRemainingSpend;

    // projectedSavings = monthly_income - fixed_monthly_expenses - projectedTotalSpend
    const projectedSavingsAtCycleEnd = monthlyIncome - fixedMonthlyExpenses - projectedTotalSpend;

    const delta = projectedSavingsAtCycleEnd - monthlySavingsGoal;
    const onTrack = delta >= 0;

    const round2 = (n: number) => Math.round(n * 100) / 100;

    console.log(
      `[bq-savings-projection] onTrack=${onTrack} projected=${round2(projectedSavingsAtCycleEnd)} goal=${monthlySavingsGoal} delta=${round2(delta)}`,
    );

    // -----------------------------------------------------------------
    // 12. Success response
    // -----------------------------------------------------------------
    return json({
      on_track: onTrack,
      currency,
      savings_goal: round2(monthlySavingsGoal),
      projected_savings: round2(projectedSavingsAtCycleEnd),
      delta: round2(delta),
      weekly_spending_rate: round2(weeklySpendingRate),
      cycle_days_remaining: cycleDaysRemaining,
      projection_basis_weeks: 2,
      expenses_count_basis: expensesCountBasis,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[bq-savings-projection] unhandled error: ${message}`);
    return json({ error: "Internal error", detail: message }, 500);
  }
});
