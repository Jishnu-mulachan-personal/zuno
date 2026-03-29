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
    const { phone, message, chatHistory, dailyInsight } = await req.json();
    if (!phone) throw new Error("Unauthorized or missing phone");
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY') ?? ''
    );

    // Fetch user details
    const { data: userData } = await supabaseClient
      .from('users')
      .select('id, display_name, relationship_id')
      .eq('phone', phone)
      .single();

    if (!userData) throw new Error("User not found");
    const relationshipId = userData.relationship_id;

    // Fetch existing summaries
    const { data: userSummaryData } = await supabaseClient
      .from('ai_summary_user_session')
      .select('summary_text')
      .eq('user_id', userData.id)
      .single();

    let relSummaryData = null;
    if (relationshipId) {
      const { data: rSummary } = await supabaseClient
        .from('ai_summary_relationship_session')
        .select('summary_text')
        .eq('relationship_id', relationshipId)
        .single();
      relSummaryData = rSummary;
    }

    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    // 1. Generate Chat Reply
    const chatPrompt = `
      You are Zuno, an empathetic AI relationship/personal companion.
      
      User: ${userData.display_name}
      Today's Insight was: "${dailyInsight}"
      
      Personal Context from previous days: ${userSummaryData?.summary_text || 'None'}
      Relationship Context: ${relSummaryData?.summary_text || 'None'}
      
      Chat History:
      ${JSON.stringify(chatHistory)}
      
      User just said: "${message}"
      
      Respond directly to the user in a warm, empathetic, and conversational way. Keep the response relatively concise (2-4 sentences max).
    `;

    const result = await model.generateContent(chatPrompt);
    const replyText = result.response.text();

    // 2. Asynchronously (or synchronously here) generate a new compressed summary of this conversation
    // to update the ai_summary_user_session and relationship sessions
    const summaryPrompt = `
      Summarize the following user state and conversation into a concise bulleted list of facts/insights about the user's feelings, relationship state, or current context. 
      This will be used as long-term memory for Zuno (the AI). 
      
      Old User Context: ${userSummaryData?.summary_text || 'None'}
      Old Relationship Context: ${relSummaryData?.summary_text || 'None'}
      
      New Conversation Snippet: 
      User: ${message}
      Zuno: ${replyText}
      
      Generate a new UPDATED personal summary for the user:
    `;

    const summaryResult = await model.generateContent(summaryPrompt);
    const newSummaryText = summaryResult.response.text();

    // Upsert the new summary back into Supabase for the user
    await supabaseClient
      .from('ai_summary_user_session')
      .upsert({ user_id: userData.id, summary_text: newSummaryText }, { onConflict: 'user_id' });

    // 3. If in a relationship, generate an update for the relationship summary as well
    if (relationshipId) {
      const relSummaryPrompt = `
        Based on this conversation, what are the key insights that should be remembered at a RELATIONSHIP level (shared memory)?
        Keep it concise and focus on the couple's dynamic if applicable.
        
        Old Relationship Context: ${relSummaryData?.summary_text || 'None'}
        Conversation: ${message} -> ${replyText}
        
        Generate the updated relationship summary:
      `;
      const relResult = await model.generateContent(relSummaryPrompt);
      const newRelSummary = relResult.response.text();

      await supabaseClient
        .from('ai_summary_relationship_session')
        .upsert({ relationship_id: relationshipId, summary_text: newRelSummary }, { onConflict: 'relationship_id' });
    }

    return new Response(JSON.stringify({ reply: replyText }), {
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
