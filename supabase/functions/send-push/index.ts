// ============================================
// SEND-PUSH — Supabase Edge Function
// ============================================
//
// Sends push notifications to GoodWatch iOS users via APNs (direct).
//
// Endpoints:
//   POST /send-push
//     body: { user_id, title, body, category?, data? }
//     — sends to a single user
//
//   POST /send-push?action=broadcast
//     body: { title, body, category?, data? }
//     — sends to ALL users with an apns_token
//
// Auth: Requires PUSH_SECRET header matching the stored secret.
// APNs: Uses JWT-based auth with the team's .p8 key.
// ============================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// --- APNs JWT Token Generation ---

async function createAPNsJWT(
  keyId: string,
  teamId: string,
  privateKeyPEM: string
): Promise<string> {
  // Parse the PEM key
  const pemContent = privateKeyPEM
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");

  const keyData = Uint8Array.from(atob(pemContent), (c) => c.charCodeAt(0));

  // Import the EC private key
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );

  // JWT Header
  const header = { alg: "ES256", kid: keyId };
  // JWT Payload — issued now, valid for 1 hour
  const now = Math.floor(Date.now() / 1000);
  const payload = { iss: teamId, iat: now };

  const encodedHeader = btoa(JSON.stringify(header))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
  const encodedPayload = btoa(JSON.stringify(payload))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  const signingInput = `${encodedHeader}.${encodedPayload}`;
  const signingInputBytes = new TextEncoder().encode(signingInput);

  // Sign with ECDSA P-256/SHA-256
  const signatureBuffer = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    signingInputBytes
  );

  // Convert DER signature to raw r||s format (64 bytes)
  const signature = new Uint8Array(signatureBuffer);
  const encodedSignature = btoa(String.fromCharCode(...signature))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");

  return `${encodedHeader}.${encodedPayload}.${encodedSignature}`;
}

// --- APNs Send ---

async function sendAPNs(
  deviceToken: string,
  payload: object,
  jwt: string,
  bundleId: string,
  isProduction: boolean
): Promise<{ success: boolean; status: number; body?: string }> {
  const host = isProduction
    ? "https://api.push.apple.com"
    : "https://api.sandbox.push.apple.com";

  const url = `${host}/3/device/${deviceToken}`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": "0",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const body = response.status === 200 ? "" : await response.text();
  return { success: response.status === 200, status: response.status, body };
}

// --- Main Handler ---

serve(async (req: Request) => {
  // CORS
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, x-push-secret",
      },
    });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
    });
  }

  // Auth check
  const pushSecret = req.headers.get("x-push-secret");
  const expectedSecret = Deno.env.get("PUSH_SECRET");
  if (!pushSecret || pushSecret !== expectedSecret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
    });
  }

  // Load APNs config from env
  const apnsKeyId = Deno.env.get("APNS_KEY_ID");
  const apnsTeamId = Deno.env.get("APNS_TEAM_ID");
  const apnsPrivateKey = Deno.env.get("APNS_PRIVATE_KEY");
  const bundleId = Deno.env.get("APNS_BUNDLE_ID") || "PJWorks.goodwatch.movies.v1";
  const isProduction = Deno.env.get("APNS_PRODUCTION") === "true";

  if (!apnsKeyId || !apnsTeamId || !apnsPrivateKey) {
    return new Response(
      JSON.stringify({ error: "APNs not configured. Set APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY." }),
      { status: 500 }
    );
  }

  // Parse request body
  const { user_id, title, body: notifBody, category, data } = await req.json();
  const url = new URL(req.url);
  const action = url.searchParams.get("action");

  if (!title || !notifBody) {
    return new Response(
      JSON.stringify({ error: "title and body are required" }),
      { status: 400 }
    );
  }

  // Build APNs payload
  const apnsPayload: any = {
    aps: {
      alert: { title, body: notifBody },
      sound: "default",
      "mutable-content": 1,
      "interruption-level": "time-sensitive",
      "thread-id": "goodwatch-picks",
    },
  };
  if (category) {
    apnsPayload.aps["category"] = category;
  }
  if (data) {
    // Merge custom data at top level (Apple convention)
    Object.assign(apnsPayload, data);
  }

  // Generate APNs JWT
  let jwt: string;
  try {
    jwt = await createAPNsJWT(apnsKeyId, apnsTeamId, apnsPrivateKey);
  } catch (err) {
    return new Response(
      JSON.stringify({ error: "Failed to create APNs JWT", detail: String(err) }),
      { status: 500 }
    );
  }

  // Initialize Supabase client
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const supabase = createClient(supabaseUrl, supabaseKey);

  // Get device tokens
  let tokens: { user_id: string; apns_token: string }[] = [];

  if (action === "broadcast") {
    // Send to ALL users with apns_token
    const { data: rows, error } = await supabase
      .from("device_tokens")
      .select("user_id, apns_token")
      .not("apns_token", "is", null)
      .eq("platform", "ios");

    if (error) {
      return new Response(
        JSON.stringify({ error: "Failed to fetch tokens", detail: error.message }),
        { status: 500 }
      );
    }
    tokens = rows || [];
  } else {
    // Send to a single user
    if (!user_id) {
      return new Response(
        JSON.stringify({ error: "user_id is required (or use ?action=broadcast)" }),
        { status: 400 }
      );
    }

    const { data: rows, error } = await supabase
      .from("device_tokens")
      .select("user_id, apns_token")
      .eq("user_id", user_id)
      .eq("platform", "ios")
      .not("apns_token", "is", null);

    if (error) {
      return new Response(
        JSON.stringify({ error: "Failed to fetch token", detail: error.message }),
        { status: 500 }
      );
    }
    tokens = rows || [];
  }

  if (tokens.length === 0) {
    return new Response(
      JSON.stringify({ sent: 0, message: "No APNs tokens found" }),
      { status: 200 }
    );
  }

  // Send to all tokens
  let sent = 0;
  let failed = 0;
  const errors: { user_id: string; status: number; body?: string }[] = [];

  for (const token of tokens) {
    if (!token.apns_token) continue;

    const result = await sendAPNs(
      token.apns_token,
      apnsPayload,
      jwt,
      bundleId,
      isProduction
    );

    if (result.success) {
      sent++;
    } else {
      failed++;
      errors.push({
        user_id: token.user_id,
        status: result.status,
        body: result.body,
      });

      // If token is invalid, clean it up
      if (result.status === 410 || result.status === 400) {
        await supabase
          .from("device_tokens")
          .update({ apns_token: null })
          .eq("user_id", token.user_id)
          .eq("platform", "ios");
      }
    }
  }

  // Log the push event
  await supabase.from("ops_log").insert({
    event_type: "push_sent",
    details: {
      action: action || "single",
      title,
      sent,
      failed,
      total_tokens: tokens.length,
    },
  });

  return new Response(
    JSON.stringify({
      sent,
      failed,
      total: tokens.length,
      errors: errors.length > 0 ? errors : undefined,
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json" },
    }
  );
});
