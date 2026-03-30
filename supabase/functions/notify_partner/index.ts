import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { identifier } = await req.json();
    if (!identifier) throw new Error("Missing identifier");

    console.log(`[notify_partner] Request received for identifier: ${identifier}`);

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const column = String(identifier).includes('@') ? 'email' : 'phone';
    
    // 1. Find the user and their relationship
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('id, relationship_id')
      .eq(column, identifier)
      .single();

    if (userError || !user) throw new Error("User not found");
    if (!user.relationship_id) throw new Error("No relationship found");

    const relationshipId = user.relationship_id;

    // 2. Find partner
    const { data: partner, error: partnerError } = await supabaseClient
      .from('users')
      .select('id, fcm_token')
      .eq('relationship_id', relationshipId)
      .neq('id', user.id)
      .single();

    if (partnerError || !partner) {
      console.log(`[notify_partner] Partner not found`);
      return new Response(JSON.stringify({ success: true, message: "No partner to notify" }), { headers: corsHeaders });
    }

    // 3. Fetch template
    const { data: template, error: templateError } = await supabaseClient
      .from('notification_templates')
      .select('message')
      .eq('type', 'partner_checkin')
      .single();

    const message = template?.message || "Your partner just checked in! 💖";

    // 4. Insert notification into user_notifications for realtime
    const { error: insertError } = await supabaseClient
      .from('user_notifications')
      .insert({
        user_id: partner.id,
        title: "Check-in Alert",
        body: message,
      });

    if (insertError) throw insertError;

    return new Response(
      JSON.stringify({ success: true, message: "Partner notified" }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );

  } catch (error: any) {
    console.error(`[notify_partner] Error: ${error.message}`);
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});
