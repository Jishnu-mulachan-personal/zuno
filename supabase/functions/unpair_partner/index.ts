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
    const { phone } = await req.json();
    if (!phone) throw new Error("Missing phone number");

    console.log(`[unpair_partner] Request received for phone: ${phone}`);

    // Initialize Supabase with Service Role Key to bypass RLS
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // 1. Find the user and their relationship
    const { data: user, error: userError } = await supabaseClient
      .from('users')
      .select('id, relationship_id')
      .eq('phone', phone)
      .single();

    if (userError || !user) throw new Error("User not found");
    if (!user.relationship_id) throw new Error("No relationship found");

    const relationshipId = user.relationship_id;
    console.log(`[unpair_partner] Found relationship: ${relationshipId}`);

    // 2. Clear relationship_id for ALL users linked to this relationship
    const { error: unlinkError } = await supabaseClient
      .from('users')
      .update({ relationship_id: null })
      .eq('relationship_id', relationshipId);

    if (unlinkError) throw unlinkError;

    // 3. Mark the relationship itself as unpaired (set partner_b_id to null)
    const { error: relError } = await supabaseClient
      .from('relationships')
      .update({ partner_b_id: null })
      .eq('id', relationshipId);

    if (relError) throw relError;

    console.log(`[unpair_partner] Successfully unpaired relationship: ${relationshipId}`);

    return new Response(
      JSON.stringify({ success: true, message: "Unpaired successfully" }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    );

  } catch (error) {
    console.error(`[unpair_partner] Error: ${error.message}`);
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});
