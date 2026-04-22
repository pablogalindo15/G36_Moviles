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

const PERIOD_DAYS = 30;
const MIN_EXPENSES = 20;
const TOP_N = 3;

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // -----------------------------------------------------------------
  // 1. Auth — validate JWT even though gateway verify is disabled
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
  // 3. Clients
  //    userClient  — validates the JWT
  //    serviceClient — bypasses RLS to aggregate across all users
  // -----------------------------------------------------------------
  const supabaseUserClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  });

  const supabaseServiceClient = createClient(supabaseUrl, supabaseServiceRoleKey);

  try {
    // -----------------------------------------------------------------
    // 4. Validate JWT — user identity is only needed for auth, not for filtering
    // -----------------------------------------------------------------
    const { data: userData, error: userError } = await supabaseUserClient.auth.getUser(
      accessToken,
    );
    if (userError || !userData.user) {
      return json({ error: "Invalid token", details: userError?.message }, 401);
    }
    console.log(`[bq-top-categories] request user=${userData.user.id}`);

    // -----------------------------------------------------------------
    // 5. Calculate period window
    // -----------------------------------------------------------------
    const now = new Date();
    const periodStart = new Date(now.getTime() - PERIOD_DAYS * 24 * 60 * 60 * 1000);
    console.log(`[bq-top-categories] period=${periodStart.toISOString()} → ${now.toISOString()}`);

    // -----------------------------------------------------------------
    // 6. Fetch category column for all expenses in the window
    //    Service client bypasses RLS to aggregate across all users.
    //    Only the category column is selected — minimal data transfer.
    // -----------------------------------------------------------------
    const { data: expenseRows, error: expensesError } = await supabaseServiceClient
      .from("expenses")
      .select("category")
      .gte("occurred_at", periodStart.toISOString())
      .lte("occurred_at", now.toISOString());

    if (expensesError) {
      return json(
        { error: "Failed to read expenses", details: expensesError.message } satisfies ErrorPayload,
        500,
      );
    }

    const totalExpenses = (expenseRows ?? []).length;
    console.log(`[bq-top-categories] total_expenses=${totalExpenses}`);

    // -----------------------------------------------------------------
    // 7. Insufficient data guard
    // -----------------------------------------------------------------
    if (totalExpenses < MIN_EXPENSES) {
      return json({
        total_expenses: totalExpenses,
        result: null,
        reason: "insufficient_data",
      });
    }

    // -----------------------------------------------------------------
    // 8. Aggregate: count occurrences per category
    // -----------------------------------------------------------------
    const counts = new Map<string, number>();
    for (const row of expenseRows ?? []) {
      const cat = row.category as string;
      counts.set(cat, (counts.get(cat) ?? 0) + 1);
    }

    // -----------------------------------------------------------------
    // 9. Sort descending by count, take top N
    // -----------------------------------------------------------------
    const sorted = [...counts.entries()].sort((a, b) => b[1] - a[1]);
    const top = sorted.slice(0, TOP_N);

    const topCategories = top.map(([category, count]) => ({
      category,
      count,
      percentage: count / totalExpenses,
    }));

    console.log(
      `[bq-top-categories] top3=${topCategories.map((c) => `${c.category}:${c.count}`).join(", ")}`,
    );

    // -----------------------------------------------------------------
    // 10. Success response
    // -----------------------------------------------------------------
    return json({
      total_expenses: totalExpenses,
      period_days: PERIOD_DAYS,
      top_categories: topCategories,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[bq-top-categories] unhandled error: ${message}`);
    return json({ error: "Internal error", detail: message }, 500);
  }
});
