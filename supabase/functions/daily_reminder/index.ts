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
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    console.log(`[daily_reminder] Starting inactivity check (20-hour window)...`);

    // 1. Fetch the gentle_reminder template
    const { data: template, error: templateError } = await supabaseClient
      .from('notification_templates')
      .select('title, message, trigger_at_utc_time')
      .eq('type', 'gentle_reminder')
      .single();

    if (templateError || !template) {
      throw new Error(`Template not found: ${templateError?.message}`);
    }

    // 2. Identify users who haven't logged in for the last 20 hours
    // We check last_login_at < NOW() - 20 hours
    const now = new Date();
    // const threshold = new Date(now.getTime() - 20 * 60 * 60 * 1000).toISOString();
    const threshold = new Date(now.getTime() - 1 * 1000).toISOString();

    const { data: users, error: usersError } = await supabaseClient
      .from('users')
      .select('id, fcm_token, display_name')
      .lt('last_login_at', threshold)
      .not('fcm_token', 'is', null);

    if (usersError) throw usersError;

    console.log(`[daily_reminder] Found ${users?.length || 0} inactive users.`);

    if (!users || users.length === 0) {
      return new Response(
        JSON.stringify({ success: true, message: "No inactive users to notify" }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      );
    }

    const results = [];

    for (const user of users) {
      try {
        console.log(`[daily_reminder] Notifying user ${user.id}`);

        // 3. Send Push Notification via shared FCM utility
        // This utility uses FIREBASE_SERVICE_ACCOUNT secret
        if (user.fcm_token) {
          try {
            await sendFCMNotification(
              user.fcm_token,
              template.title || "Hey, Friend! ✨",
              template.message,
              { type: 'gentle_reminder' }
            );
          } catch (fcmErr: any) {
            console.error(`[daily_reminder] FCM delivery failed for user ${user.id}: ${fcmErr.message}`);
            // We continue to record the in-app notification even if FCM fails
          }
        }

        // 4. Insert into user_notifications for in-app history/realtime sync
        await supabaseClient.from('user_notifications').insert({
          user_id: user.id,
          title: template.title || 'Daily Reminder',
          body: template.message,
        });

        results.push({ userId: user.id, status: 'success' });
      } catch (err: any) {
        console.error(`[daily_reminder] Processing error for user ${user.id}: ${err.message}`);
        results.push({ userId: user.id, status: 'error', error: err.message });
      }
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        processedCount: users.length,
        summary: results
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );

  } catch (error: any) {
    console.error(`[daily_reminder] Fatal Error: ${error.message}`);
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});
