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
  // 2. Parse body — week_end is optional (defaults to now)
  // -----------------------------------------------------------------
  let body: { week_end?: unknown } = {};
  try {
    body = await req.json();
  } catch {
    // Empty or missing body is fine — we use defaults below.
  }

  const weekEnd = body.week_end ? new Date(body.week_end as string) : new Date();
  const weekStart = new Date(weekEnd.getTime() - 7 * 24 * 60 * 60 * 1000);

  // -----------------------------------------------------------------
  // 3. Environment variables
  // -----------------------------------------------------------------
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return json(
      {
        error: "Missing required environment variables",
        details: "SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are required",
      } satisfies ErrorPayload,
      500,
    );
  }

  // -----------------------------------------------------------------
  // 4. Two Supabase clients
  //    - userClient:    sends the user JWT so RLS is enforced
  //    - serviceClient: uses service role key to bypass RLS for cross-user cohort queries
  // -----------------------------------------------------------------
  const supabaseUserClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  });

  const supabaseServiceClient = createClient(supabaseUrl, supabaseServiceRoleKey);

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
    console.log(`[bq-comparative] request user=${userId} weekStart=${weekStart.toISOString()}`);

    // -----------------------------------------------------------------
    // 6. Read the user's most recent financial setup (RLS: own row only)
    // -----------------------------------------------------------------
    const { data: setupRows, error: setupError } = await supabaseUserClient
      .from("financial_setups")
      .select("monthly_income, currency")
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
      return json({ error: "No financial setup found for user" }, 404);
    }

    // monthly_income is stored as NUMERIC in Postgres and arrives as a string in JS.
    const myIncome = Number(setupRows[0].monthly_income);
    const myCurrency = String(setupRows[0].currency).toUpperCase();
    console.log(`[bq-comparative] myIncome=${myIncome} myCurrency=${myCurrency}`);

    // -----------------------------------------------------------------
    // 7. Identify cohort: same currency + monthly_income within ±25%
    //    Uses service client to bypass RLS so we can see other users' setups.
    //    A user may have multiple setup rows — deduplicate by user_id.
    // -----------------------------------------------------------------
    const { data: cohortSetupRows, error: cohortError } = await supabaseServiceClient
      .from("financial_setups")
      .select("user_id")
      .eq("currency", myCurrency)
      .gte("monthly_income", myIncome * 0.75)
      .lte("monthly_income", myIncome * 1.25);

    if (cohortError) {
      return json(
        { error: "Failed to read cohort data", details: cohortError.message } satisfies ErrorPayload,
        500,
      );
    }

    const cohortUserIds = [
      ...new Set((cohortSetupRows ?? []).map((r: { user_id: string }) => r.user_id)),
    ];
    const cohortSize = cohortUserIds.length;
    console.log(`[bq-comparative] cohort_size=${cohortSize}`);

    // -----------------------------------------------------------------
    // 8. Cohort too small — return early without exposing individual data
    // -----------------------------------------------------------------
    if (cohortSize < 5) {
      return json({ cohort_size: cohortSize, result: null, reason: "cohort_too_small" });
    }

    // -----------------------------------------------------------------
    // 9. Fetch expenses for cohort in the 7-day window
    //    Uses service client (RLS bypass) to aggregate across users.
    // -----------------------------------------------------------------
    const { data: expenseRows, error: expensesError } = await supabaseServiceClient
      .from("expenses")
      .select("user_id, amount")
      .in("user_id", cohortUserIds)
      .eq("currency", myCurrency)
      .gte("occurred_at", weekStart.toISOString())
      .lte("occurred_at", weekEnd.toISOString());

    if (expensesError) {
      return json(
        { error: "Failed to read expenses", details: expensesError.message } satisfies ErrorPayload,
        500,
      );
    }

    // -----------------------------------------------------------------
    // 10. Aggregate in JS — sum per user_id
    //     NUMERIC/DECIMAL columns from Postgres arrive as strings in JS.
    //     Always convert with Number() before arithmetic.
    // -----------------------------------------------------------------
    const sumsByUser = new Map<string, number>();
    for (const row of expenseRows ?? []) {
      const uid = row.user_id as string;
      const amt = Number(row.amount); // explicit cast: Postgres DECIMAL → string → number
      sumsByUser.set(uid, (sumsByUser.get(uid) ?? 0) + amt);
    }

    // Users with zero expenses in the window are still cohort members (0 is valid).
    for (const uid of cohortUserIds) {
      if (!sumsByUser.has(uid)) {
        sumsByUser.set(uid, 0);
      }
    }

    // -----------------------------------------------------------------
    // 11. Compute stats
    // -----------------------------------------------------------------
    const mySpending = sumsByUser.get(userId) ?? 0;
    const allSums = [...sumsByUser.values()].sort((a, b) => a - b);
    const cohortAvg = allSums.reduce((a, b) => a + b, 0) / allSums.length;

    // Percentile replicates Postgres PERCENT_RANK():
    //   rank of a value = fraction of values strictly below it in a sorted list
    //   = countBelow / (n - 1)   (0 when everyone has the same value or n === 1)
    const countBelow = allSums.filter((v) => v < mySpending).length;
    const myPercentile = allSums.length > 1 ? countBelow / (allSums.length - 1) : 0;

    console.log(
      `[bq-comparative] result: my_spending=${mySpending} avg=${cohortAvg.toFixed(2)} percentile=${myPercentile.toFixed(2)}`,
    );

    // -----------------------------------------------------------------
    // 12. Success response
    // -----------------------------------------------------------------
    return json({
      my_weekly_spending: mySpending,
      cohort_avg_weekly_spending: cohortAvg,
      cohort_size: cohortSize,
      my_percentile: myPercentile,
      currency: myCurrency,
      week_start: weekStart.toISOString(),
      week_end: weekEnd.toISOString(),
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[bq-comparative] unhandled error: ${message}`);
    return json({ error: "Internal error", detail: message }, 500);
  }
});
