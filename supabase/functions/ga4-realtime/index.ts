import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

let cachedGoogleToken = "";
let cachedGoogleTokenExpiry = 0;

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function decodePem(pem: string): Uint8Array {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "").replace(/\s/g, "");
  const binary = atob(body);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}

async function getGoogleAccessToken(serviceAccount: {
  client_email: string;
  private_key: string;
  token_uri?: string;
}): Promise<string> {
  if (cachedGoogleToken && Date.now() < cachedGoogleTokenExpiry - 60_000) return cachedGoogleToken;

  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/analytics.readonly",
    aud: serviceAccount.token_uri || "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = header + "." + claims;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    decodePem(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  ));
  const assertion = unsigned + "." + base64Url(signature);

  const tokenResponse = await fetch(serviceAccount.token_uri || "https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const tokenData = await tokenResponse.json();
  if (!tokenResponse.ok || !tokenData.access_token) {
    throw new Error("Google no autorizó la consulta de Analytics.");
  }
  cachedGoogleToken = tokenData.access_token;
  cachedGoogleTokenExpiry = Date.now() + Number(tokenData.expires_in || 3600) * 1000;
  return cachedGoogleToken;
}

async function runRealtimeReport(propertyId: string, accessToken: string, withPages: boolean) {
  const body: Record<string, unknown> = {
    metrics: [{ name: "activeUsers" }],
    limit: withPages ? 10 : 1,
  };
  if (withPages) {
    body.dimensions = [{ name: "pagePath" }];
    body.orderBys = [{ metric: { metricName: "activeUsers" }, desc: true }];
  }

  const response = await fetch(
    `https://analyticsdata.googleapis.com/v1beta/properties/${propertyId}:runRealtimeReport`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
    },
  );
  const result = await response.json();
  if (!response.ok) {
    console.error("GA4 API error:", result);
    throw new Error("Google Analytics no pudo devolver el informe en tiempo real.");
  }
  return result;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ success: false, error: "Método no permitido." }), {
      status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const authHeader = request.headers.get("Authorization");
    if (!supabaseUrl || !anonKey || !authHeader) {
      return new Response(JSON.stringify({ success: false, error: "Sesión no válida." }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const jwt = authHeader.replace(/^Bearer\s+/i, "");
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ success: false, error: "Inicia sesión para consultar las estadísticas." }), {
        status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { data: isAdmin, error: adminError } = await supabase.rpc("is_mazwave_admin");
    if (adminError || isAdmin !== true) {
      return new Response(JSON.stringify({ success: false, error: "No tienes permisos para consultar estas estadísticas." }), {
        status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const propertyId = Deno.env.get("GA4_PROPERTY_ID") || "565034925";
    const serviceAccountRaw = Deno.env.get("GA4_SERVICE_ACCOUNT_JSON");
    if (!serviceAccountRaw) throw new Error("Falta configurar la cuenta de servicio de Google Analytics en Supabase.");

    const serviceAccount = JSON.parse(serviceAccountRaw);
    if (!serviceAccount.client_email || !serviceAccount.private_key) {
      throw new Error("La credencial de Google no tiene client_email o private_key.");
    }

    const accessToken = await getGoogleAccessToken(serviceAccount);
    const [totalReport, pagesReport] = await Promise.all([
      runRealtimeReport(propertyId, accessToken, false),
      runRealtimeReport(propertyId, accessToken, true),
    ]);

    const activeUsers = Number(totalReport.rows?.[0]?.metricValues?.[0]?.value || 0);
    const pages = (pagesReport.rows || []).map((row: {
      dimensionValues?: Array<{ value?: string }>;
      metricValues?: Array<{ value?: string }>;
    }) => ({
      path: row.dimensionValues?.[0]?.value || "/",
      activeUsers: Number(row.metricValues?.[0]?.value || 0),
    }));

    return new Response(JSON.stringify({
      success: true,
      activeUsers,
      pages,
      generatedAt: new Date().toISOString(),
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json", "Cache-Control": "no-store" },
    });
  } catch (error) {
    console.error("ga4-realtime:", error);
    return new Response(JSON.stringify({
      success: false,
      error: error instanceof Error ? error.message : "No se pudo consultar Analytics.",
    }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
