import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const reqBody = await req.json();
    const phone = reqBody.phone;
    if (!phone) throw new Error("Unauthorized or missing phone");

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    );

    // Fetch user details to get relationship_id
    const { data: userData } = await supabaseClient
      .from('users')
      .select('id, display_name, relationship_id')
      .eq('phone', phone)
      .single();

    if (!userData) throw new Error("User not found");

    const relationshipId = userData.relationship_id;

    // Fetch logs from the last 2 days for the user and their partner (if any)
    const twoDaysAgo = new Date();
    twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
    const dateString = twoDaysAgo.toISOString();

    let logsQuery = supabaseClient
      .from('daily_logs')
      .select('user_id, log_date, mood_emoji, connection_felt, context_tags, users(display_name)')
      .gte('log_date', dateString);

    if (relationshipId) {
      // Fetch users in this relationship to filter logs
      const { data: relationshipUsers } = await supabaseClient
        .from('users')
        .select('id')
        .eq('relationship_id', relationshipId);
      
      const userIds = relationshipUsers?.map(u => u.id) || [userData.id];
      logsQuery = logsQuery.in('user_id', userIds);
    } else {
      logsQuery = logsQuery.eq('user_id', userData.id);
    }

    const { data: recentLogs } = await logsQuery;

    // Fetch personal AI summary context
    const { data: userSummary } = await supabaseClient
      .from('ai_summary_user_session')
      .select('summary_text')
      .eq('user_id', userData.id)
      .single();

    // Fetch relationship AI summary context (if applicable)
    let relSummary = null;
    if (relationshipId) {
      const { data: rSummary } = await supabaseClient
        .from('ai_summary_relationship_session')
        .select('summary_text')
        .eq('relationship_id', relationshipId)
        .single();
      relSummary = rSummary;
    }

    // Build the prompt for Gemini Flash
    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    const prompt = `
      You are Zuno, an empathetic AI companion for individuals and couples.
      Your goal is to provide a short, encouraging, and insightful daily message (about 2-3 sentences).
      
      User: ${userData.display_name}
      Personal AI Context (previous conversations): ${userSummary?.summary_text || 'None yet.'}
      Relationship AI Context: ${relSummary?.summary_text || 'None yet.'}
      
      Recent Activity (Last 2 Days):
      ${JSON.stringify(recentLogs, null, 2)}
      
      Based on this data, write a brief, warm, and highly personalized insight for today. Do not be overly dramatic, just supportive and observant.
    `;

    const result = await model.generateContent(prompt);
    const text = result.response.text();

    return new Response(JSON.stringify({ insight: text }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
