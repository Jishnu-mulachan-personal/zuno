import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendFCMNotification } from "../_shared/fcm.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { identifier, type = 'partner_checkin', displayName } = await req.json();
    if (!identifier) throw new Error("Missing identifier");

    console.log(`[notify_partner] Request received for identifier: ${identifier}, type: ${type}`);

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    const column = String(identifier).includes('@') ? 'email' : 'phone';
    
    // 1. Find the user and their relationship
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('id, relationship_id, display_name')
      .eq(column, identifier)
      .single();

    if (userError || !user) throw new Error("User not found");
    if (!user.relationship_id) throw new Error("No relationship found");

    const relationshipId = user.relationship_id;
    const authorName = displayName || user.display_name || "Your partner";

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
      .select('title, message')
      .eq('type', type)
      .single();

    let message = template?.message || "Something new shared with you! 💖";
    const title = template?.title || "Update from Zuno";

    // Personalize message if it contains placeholders or just prepend/replace
    if (message.includes('Your partner')) {
      message = message.replace('Your partner', authorName);
    }

    // 4. Insert notification into user_notifications for realtime
    const { error: insertError } = await supabaseClient
      .from('user_notifications')
      .insert({
        user_id: partner.id,
        title: title,
        body: message,
      });

    if (insertError) throw insertError;
    console.log(`[notify_partner] Inserted notification for user ${partner.id}`);

    // 5. Send FCM Notification for terminated app state
    if (partner.fcm_token) {
      try {
        await sendFCMNotification(
          partner.fcm_token,
          title,
          message,
          { type: type, relationship_id: relationshipId }
        );
        console.log(`[notify_partner] Sent FCM notification to partner ${partner.id}`);
      } catch (fcmError: any) {
        console.error(`[notify_partner] FCM Error: ${fcmError.message}`);
        // Continuing as database notification was successful
      }
    } else {
      console.log(`[notify_partner] No FCM token for partner ${partner.id}`);
    }

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
