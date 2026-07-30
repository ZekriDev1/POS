// Check license key status (admin tool)
// Deploy: supabase functions deploy check-license --no-verify-jwt
// Usage: curl -X POST https://PROJECT_REF.functions.supabase.co/check-license \
//   -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
//   -H "Content-Type: application/json" \
//   -d '{"license_key": "RESTROPOS-XXXX-XXXX-XXXX"}'

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

interface CheckRequest {
  license_key: string;
}

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }

    const { license_key }: CheckRequest = await req.json();
    if (!license_key) {
      return new Response(
        JSON.stringify({ found: false, error: "Missing license_key" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    const { data: license, error } = await supabase
      .from("licenses")
      .select("*")
      .eq("license_key", license_key)
      .maybeSingle();

    if (error) {
      return new Response(
        JSON.stringify({ found: false, error: "Database error" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!license) {
      return new Response(
        JSON.stringify({ found: false, message: "License key does not exist" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const now = new Date();
    const isLifetime = !license.expires_at;
    const expired = !isLifetime && new Date(license.expires_at) < now;
    const activated = license.is_active && !!license.device_id;

    let status = "disabled";
    if (!license.is_active) status = "disabled";
    else if (expired) status = "expired";
    else if (activated) status = "activated";
    else if (isLifetime) status = "lifetime — available";
    else status = "available";

    return new Response(
      JSON.stringify({
        found: true,
        license_key: license.license_key,
        is_active: license.is_active,
        is_activated: activated,
        is_expired: expired,
        is_lifetime: isLifetime,
        device_id: license.device_id || null,
        activated_at: license.activated_at,
        expires_at: license.expires_at,
        created_at: license.created_at,
        status: status,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ found: false, error: err.message }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
