const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function getBearerToken(req: Request): string | null {
  const auth = req.headers.get("authorization");
  if (!auth) return null;
  return auth.toLowerCase().startsWith("bearer ") ? auth.slice(7) : auth;
}

// Maps ISO country code to its primary currency code.
const COUNTRY_TO_CURRENCY: Record<string, string> = {
  US: "USD", CO: "COP", MX: "MXN", ES: "EUR", FR: "EUR", DE: "EUR",
  IT: "EUR", PT: "EUR", BR: "BRL", AR: "ARS", PE: "PEN", CL: "CLP",
  VE: "VES", EC: "USD", PA: "USD", CR: "CRC", GT: "GTQ", HN: "HNL",
  SV: "USD", NI: "NIO", DO: "DOP", CU: "CUP", GB: "GBP", CA: "CAD",
  AU: "AUD", JP: "JPY", CN: "CNY", IN: "INR", KR: "KRW", CH: "CHF",
  SE: "SEK", NO: "NOK", DK: "DKK", PL: "PLN", CZ: "CZK", HU: "HUF",
  RO: "RON", TR: "TRY", RU: "RUB", ZA: "ZAR", NG: "NGN", EG: "EGP",
  KE: "KES", GH: "GHS", MA: "MAD", TH: "THB", SG: "SGD", MY: "MYR",
  ID: "IDR", PH: "PHP", VN: "VND", PK: "PKR", BD: "BDT", NZ: "NZD",
  SA: "SAR", AE: "AED", QA: "QAR", KW: "KWD", BO: "BOB", PY: "PYG",
  UY: "UYU",
};

// Fetches the latest annual inflation rate for a country from the World Bank API.
async function fetchInflationRate(countryCode: string): Promise<number | null> {
  try {
    const url =
      `https://api.worldbank.org/v2/country/${countryCode}/indicator/FP.CPI.TOTL.ZG` +
      `?format=json&mrv=1&per_page=1`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const data = await res.json();
    const value = data?.[1]?.[0]?.value;
    return typeof value === "number" ? value : null;
  } catch {
    return null;
  }
}

function buildInflationWarning(
  inflationRate: number | null,
  currency: string
): string | null {
  if (inflationRate === null) return null;
  if (inflationRate > 30) {
    return `${currency} is experiencing very high inflation (${inflationRate.toFixed(1)}% annually). Consider saving a portion of your money in a more stable currency such as USD or EUR.`;
  }
  if (inflationRate > 10) {
    return `${currency} has elevated inflation (${inflationRate.toFixed(1)}% annually). Consider diversifying your savings to protect your purchasing power.`;
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  // Supabase auto-validates the JWT before the function runs.
  // Just confirm the Authorization header is present.
  if (!getBearerToken(req)) {
    return json({ error: "Missing Authorization Bearer token" }, 401);
  }

  // Parse body.
  let body: { latitude?: unknown; longitude?: unknown; country_code?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "Body must be valid JSON" }, 400);
  }

  const latitude = Number(body.latitude);
  const longitude = Number(body.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return json({ error: "latitude and longitude must be valid numbers" }, 400);
  }

  // Use device-resolved country code if provided; otherwise fall back to Nominatim.
  let countryCode: string | null =
    typeof body.country_code === "string" && body.country_code.length === 2
      ? body.country_code.toUpperCase()
      : null;

  if (!countryCode) {
    try {
      const nominatimUrl =
        `https://nominatim.openstreetmap.org/reverse` +
        `?lat=${latitude}&lon=${longitude}&format=json&accept-language=en`;
      const geoRes = await fetch(nominatimUrl, {
        headers: { "User-Agent": "FluxoApp/1.0" },
      });
      if (geoRes.ok) {
        const geoData = await geoRes.json();
        countryCode = geoData?.address?.country_code?.toUpperCase() ?? null;
      }
    } catch {
      // If geocoding fails, continue with defaults.
    }
  }

  const currency = (countryCode && COUNTRY_TO_CURRENCY[countryCode]) ?? "USD";

  // Fetch inflation data from World Bank.
  const inflationRate = countryCode ? await fetchInflationRate(countryCode) : null;
  const inflationWarning = buildInflationWarning(inflationRate, currency);

  return json({
    country_code: countryCode ?? "UNKNOWN",
    currency,
    inflation_rate: inflationRate,
    inflation_warning: inflationWarning,
  });
});
