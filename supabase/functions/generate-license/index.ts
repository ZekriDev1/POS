// Admin: Generate new license keys
// Deploy: supabase functions deploy generate-license --no-verify-jwt
// Usage: curl -X POST https://PROJECT_REF.functions.supabase.co/generate-license \
//   -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
//   -H "Content-Type: application/json" \
//   -d '{"count": 1, "expires_in_days": 365}'

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface GenerateRequest {
  count?: number;
  expires_in_days?: number;
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

function generateKey(): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  const segments: string[] = [];
  for (let s = 0; s < 4; s++) {
    let segment = "";
    for (let i = 0; i < 4; i++) {
      segment += chars[Math.floor(Math.random() * chars.length)];
    }
    segments.push(segment);
  }
  return `RESTROPOS-${segments.join("-")}`;
}

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const { count = 1, expires_in_days = 365 }: GenerateRequest = await req.json();
    const limit = Math.min(Math.max(count, 1), 50);
    const keys: string[] = [];
    const errors: string[] = [];

    for (let i = 0; i < limit; i++) {
      let licenseKey = generateKey();
      let attempts = 0;

      // Ensure uniqueness
      while (attempts < 10) {
        const { data: existing } = await supabase
          .from("licenses")
          .select("id")
          .eq("license_key", licenseKey)
          .maybeSingle();

        if (!existing) break;
        licenseKey = generateKey();
        attempts++;
      }

      if (attempts >= 10) {
        errors.push(`Failed to generate unique key at index ${i}`);
        continue;
      }

      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + expires_in_days);

      const { error: insertError } = await supabase.from("licenses").insert({
        license_key: licenseKey,
        is_active: true,
        expires_at: expiresAt.toISOString(),
      });

      if (insertError) {
        errors.push(`DB insert failed for key ${licenseKey}: ${insertError.message}`);
      } else {
        keys.push(licenseKey);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        generated: keys.length,
        errors: errors.length,
        keys: keys,
        error_details: errors.length > 0 ? errors : undefined,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ success: false, error: err.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
