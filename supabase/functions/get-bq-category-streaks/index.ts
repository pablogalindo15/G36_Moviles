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

const KNOWN_CATEGORIES = [
  "food",
  "transport",
  "entertainment",
  "health",
  "shopping",
  "bills",
  "other",
];

const CAP_DAYS = 30;
const TOP_N = 3;

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
    console.log(`[bq-category-streaks] request user=${userId}`);

    // -----------------------------------------------------------------
    // 5. Fetch the most recent occurred_at per category
    //    We only need category + occurred_at — minimal data transfer.
    // -----------------------------------------------------------------
    const { data: expenseRows, error: expensesError } = await supabaseUserClient
      .from("expenses")
      .select("category, occurred_at")
      .eq("user_id", userId)
      .order("occurred_at", { ascending: false });

    if (expensesError) {
      return json(
        { error: "Failed to read expenses", details: expensesError.message } satisfies ErrorPayload,
        500,
      );
    }

    // -----------------------------------------------------------------
    // 6. Find the latest occurred_at per category in JS
    // -----------------------------------------------------------------
    const latestByCategory = new Map<string, Date>();
    for (const row of expenseRows ?? []) {
      const cat = row.category as string;
      if (!latestByCategory.has(cat)) {
        latestByCategory.set(cat, new Date(row.occurred_at as string));
      }
    }

    const now = new Date();
    console.log(`[bq-category-streaks] evaluatedAt=${now.toISOString()}`);

    // -----------------------------------------------------------------
    // 7. Compute days_since_last for every known category
    //    Categories with no expenses ever are excluded (no data to show).
    // -----------------------------------------------------------------
    const streaks: Array<{ category: string; days_since_last: number; capped: boolean }> = [];

    for (const category of KNOWN_CATEGORIES) {
      const lastDate = latestByCategory.get(category);
      if (!lastDate) continue; // never used — skip

      const rawDays = Math.floor((now.getTime() - lastDate.getTime()) / (1000 * 60 * 60 * 24));
      const capped = rawDays > CAP_DAYS;
      const daysSinceLast = capped ? CAP_DAYS : rawDays;

      streaks.push({ category, days_since_last: daysSinceLast, capped });
    }

    // -----------------------------------------------------------------
    // 8. Sort descending by days_since_last, take top N
    // -----------------------------------------------------------------
    streaks.sort((a, b) => b.days_since_last - a.days_since_last);
    const topStreaks = streaks.slice(0, TOP_N);

    console.log(
      `[bq-category-streaks] top3=${topStreaks.map((s) => `${s.category}:${s.days_since_last}d`).join(", ")}`,
    );

    // -----------------------------------------------------------------
    // 9. Success response
    // -----------------------------------------------------------------
    return json({
      evaluated_at: now.toISOString(),
      streaks: topStreaks,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`[bq-category-streaks] unhandled error: ${message}`);
    return json({ error: "Internal error", detail: message }, 500);
  }
});
