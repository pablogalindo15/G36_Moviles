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
  // 2. Environment variables
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
  // 3. Single Supabase client with user JWT (RLS enforced — personal data only)
  // -----------------------------------------------------------------
  const supabaseUserClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  });

  try {
    // -----------------------------------------------------------------
    // 4. Validate JWT + resolve current user
    // -----------------------------------------------------------------
    const { data: userData, error: userError } = await supabaseUserClient.auth.getUser(
      accessToken,
    );
    if (userError || !userData.user) {
      return json({ error: "Invalid token", details: userError?.message }, 401);
    }
    const userId = userData.user.id;
    console.log(`[bq-category-cycle-comparison] request user=${userId}`);

    // -----------------------------------------------------------------
    // 5. Read the user's most recent financial setup to get next_payday
    // -----------------------------------------------------------------
    const { data: setupRows, error: setupError } = await supabaseUserClient
      .from("financial_setups")
      .select("next_payday, currency")
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
    if (!setup.next_payday) {
      return json({ error: "No next_payday configured" }, 404);
    }

    const currency = String(setup.currency).toUpperCase();

    // -----------------------------------------------------------------
    // 6. Calculate cycle boundaries
    //    current cycle:  last_payday → next_payday
    //    previous cycle: two_paydays_ago → last_payday
    //    Approximation: each cycle is exactly 1 month.
    // -----------------------------------------------------------------
    const nextPaydayDate = new Date(setup.next_payday);
    const cycleEnd = nextPaydayDate;

    const cycleStart = new Date(nextPaydayDate);
    cycleStart.setMonth(cycleStart.getMonth() - 1);

    const previousCycleStart = new Date(cycleStart);
    previousCycleStart.setMonth(previousCycleStart.getMonth() - 1);
    const previousCycleEnd = cycleStart;

    console.log(
      `[bq-category-cycle-comparison] current=${cycleStart.toISOString()}→${cycleEnd.toISOString()} previous=${previousCycleStart.toISOString()}→${previousCycleEnd.toISOString()}`,
    );

    // -----------------------------------------------------------------
    // 7. Fetch expenses for current cycle
    // -----------------------------------------------------------------
    const { data: currentRows, error: currentError } = await supabaseUserClient
      .from("expenses")
      .select("category, amount")
      .eq("user_id", userId)
      .eq("currency", currency)
      .gte("occurred_at", cycleStart.toISOString())
      .lt("occurred_at", cycleEnd.toISOString());

    if (currentError) {
      return json(
        { error: "Failed to read current cycle expenses", details: currentError.message } satisfies ErrorPayload,
        500,
      );
    }

    // -----------------------------------------------------------------
    // 8. Fetch expenses for previous cycle
    // -----------------------------------------------------------------
    const { data: previousRows, error: previousError } = await supabaseUserClient
      .from("expenses")
      .select("category, amount")
      .eq("user_id", userId)
      .eq("currency", currency)
      .gte("occurred_at", previousCycleStart.toISOString())
      .lt("occurred_at", previousCycleEnd.toISOString());

    if (previousError) {
      return json(
        { error: "Failed to read previous cycle expenses", details: previousError.message } satisfies ErrorPayload,
        500,
      );
    }

    // -----------------------------------------------------------------
    // 9. Aggregate by category in JS
    // -----------------------------------------------------------------
    const currentTotals = new Map<string, number>();
    for (const row of currentRows ?? []) {
      const cat = row.category as string;
      currentTotals.set(cat, (currentTotals.get(cat) ?? 0) + Number(row.amount));
    }

    const previousTotals = new Map<string, number>();
    for (const row of previousRows ?? []) {
      const cat = row.category as string;
      previousTotals.set(cat, (previousTotals.get(cat) ?? 0) + Number(row.amount));
    }

    // Union of all categories seen in either cycle
    const allCategories = new Set([...currentTotals.keys(), ...previousTotals.keys()]);

    const round2 = (n: number) => Math.round(n * 100) / 100;

    const categories = [...allCategories].map((category) => {
      const currentAmount = round2(currentTotals.get(category) ?? 0);
      const previousAmount = round2(previousTotals.get(category) ?? 0);
      const deltaAmount = round2(currentAmount - previousAmount);
      const deltaPercent =
        previousAmount === 0 ? null : round2((deltaAmount / previousAmount) * 100);

      return { category, current_amount: currentAmount, previous_amount: previousAmount, delta_amount: deltaAmount, delta_percent: deltaPercent };
    });

    // Sort by current_amount descending
    categories.sort((a, b) => b.current_amount - a.current_amount);

    console.log(
      `[bq-category-cycle-comparison] categories=${categories.length} currentRows=${(currentRows ?? []).length} previousRows=${(previousRows ?? []).length}`,
    );

    // -----------------------------------------------------------------
    // 10. Success response
    // -----------------------------------------------------------------
    return json({
      currency,
      cycle_start: cycleStart.toISOString().split("T")[0],
      cycle_end: cycleEnd.toISOString().split("T")[0],
      previous_cycle_start: previousCycleStart.toISOString().split("T")[0],
      categories,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[bq-category-cycle-comparison] unhandled error: ${message}`);
    return json({ error: "Internal error", detail: message }, 500);
  }
});
