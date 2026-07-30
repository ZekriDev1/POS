// RestroPOS License Validation Edge Function
// Deploy: supabase functions deploy validate-license --no-verify-jwt

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ valid: false, message: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { license_key, device_id } = await req.json();

    if (!license_key || !device_id) {
      return new Response(JSON.stringify({ valid: false, message: "Missing license_key or device_id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Find the license (maybeSingle to avoid 406 if not found)
    const { data: license, error: findError } = await supabase
      .from("licenses")
      .select("*")
      .eq("license_key", license_key)
      .maybeSingle();

    if (findError || !license) {
      return new Response(JSON.stringify({ valid: false, message: "Invalid license key" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Check if license is disabled
    if (!license.is_active) {
      return new Response(JSON.stringify({ valid: false, message: "License key is disabled" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Check if expired (only if expires_at is set)
    if (license.expires_at && new Date(license.expires_at) < new Date()) {
      return new Response(JSON.stringify({ valid: false, message: "License has expired" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Check if already used on another device
    if (license.device_id && license.device_id !== device_id) {
      return new Response(JSON.stringify({
        valid: false,
        message: "This license key is already in use on another device",
        code: "ALREADY_USED",
      }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Activate
    const { error: updateError } = await supabase
      .from("licenses")
      .update({
        device_id: device_id,
        activated_at: new Date().toISOString(),
        last_validated_at: new Date().toISOString(),
        is_active: true,
      })
      .eq("id", license.id);

    if (updateError) {
      return new Response(JSON.stringify({ valid: false, message: "Activation failed" }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ valid: true, message: "License activated successfully" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ valid: false, message: "Internal server error" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
