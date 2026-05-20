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
    console.log(`[bq-biggest-expense-of-cycle] request user=${userId}`);

    // -----------------------------------------------------------------
    // 5. Read the user's most recent financial setup
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
    // 6. Calculate current cycle boundaries
    //    current cycle: last_payday (next_payday - 1 month) → next_payday
    // -----------------------------------------------------------------
    const nextPaydayDate = new Date(setup.next_payday);
    const cycleEnd = nextPaydayDate;

    const cycleStart = new Date(nextPaydayDate);
    cycleStart.setMonth(cycleStart.getMonth() - 1);

    console.log(
      `[bq-biggest-expense-of-cycle] cycle=${cycleStart.toISOString()}→${cycleEnd.toISOString()}`,
    );

    // -----------------------------------------------------------------
    // 7. Read the most recent generated plan for safe_to_spend budget
    // -----------------------------------------------------------------
    const { data: planRows, error: planError } = await supabaseUserClient
      .from("generated_plans")
      .select("safe_to_spend_until_next_payday")
      .eq("user_id", userId)
      .order("generated_at", { ascending: false })
      .limit(1);

    if (planError) {
      return json(
        { error: "Failed to read generated plan", details: planError.message } satisfies ErrorPayload,
        500,
      );
    }

    const budget =
      planRows && planRows.length > 0
        ? Number(planRows[0].safe_to_spend_until_next_payday)
        : null;

    // -----------------------------------------------------------------
    // 8. Fetch all expenses in current cycle
    // -----------------------------------------------------------------
    const { data: cycleRows, error: cycleError } = await supabaseUserClient
      .from("expenses")
      .select("amount, category, occurred_at, note")
      .eq("user_id", userId)
      .eq("currency", currency)
      .gte("occurred_at", cycleStart.toISOString())
      .lt("occurred_at", cycleEnd.toISOString());

    if (cycleError) {
      return json(
        { error: "Failed to read cycle expenses", details: cycleError.message } satisfies ErrorPayload,
        500,
      );
    }

    if (!cycleRows || cycleRows.length === 0) {
      return json({
        currency,
        cycle_start: cycleStart.toISOString().split("T")[0],
        cycle_end: cycleEnd.toISOString().split("T")[0],
        biggest: null,
        reason: "no_expenses_in_cycle",
      });
    }

    // -----------------------------------------------------------------
    // 9. Find the biggest expense in JS
    // -----------------------------------------------------------------
    let biggestRow = cycleRows[0];
    for (const row of cycleRows) {
      if (Number(row.amount) > Number(biggestRow.amount)) {
        biggestRow = row;
      }
    }

    const round2 = (n: number) => Math.round(n * 100) / 100;

    const amount = round2(Number(biggestRow.amount));
    const percentOfBudget =
      budget !== null && budget > 0 ? round2((amount / budget) * 100) : null;

    console.log(
      `[bq-biggest-expense-of-cycle] biggest=${amount} ${currency} budget=${budget} percent=${percentOfBudget}`,
    );

    // -----------------------------------------------------------------
    // 10. Success response
    // -----------------------------------------------------------------
    return json({
      currency,
      cycle_start: cycleStart.toISOString().split("T")[0],
      cycle_end: cycleEnd.toISOString().split("T")[0],
      biggest: {
        amount,
        category: biggestRow.category as string,
        occurred_at: biggestRow.occurred_at as string,
        note: (biggestRow.note as string | null) ?? null,
        percent_of_budget: percentOfBudget,
      },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[bq-biggest-expense-of-cycle] unhandled error: ${message}`);
    return json({ error: "Internal error", detail: message }, 500);
  }
});
