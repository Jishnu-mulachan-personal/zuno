import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai";
import { decryptFernet } from "../_shared/fernet.ts";

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

    const fernetKey = Deno.env.get('FERNET_KEY');
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Get User and Relationship Context
    const { data: userData } = await supabaseClient
      .from('users')
      .select('id, display_name, relationship_id')
      .eq('phone', phone)
      .single();

    if (!userData) throw new Error("User not found");
    const relationshipId = userData.relationship_id;

    // 2. Fetch "Last Row" (Latest Context) from summary tables
    const { data: userSummary } = await supabaseClient
      .from('ai_summary_user_session')
      .select('summary_text')
      .eq('user_id', userData.id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    let relSummary = null;
    if (relationshipId) {
      const { data: rSum } = await supabaseClient
        .from('ai_summary_relationship_session')
        .select('summary_text')
        .eq('relationship_id', relationshipId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      relSummary = rSum;
    }

    // 3. Fetch Decrypted Logs (Including Partner Public Notes)
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();
    
    // Get all user IDs in the relationship to check logs
    let relevantUserIds = [userData.id];
    if (relationshipId) {
      const { data: partners } = await supabaseClient.from('users').select('id').eq('relationship_id', relationshipId);
      relevantUserIds = partners?.map(p => p.id) || [userData.id];
    }

    const { data: recentLogs } = await supabaseClient
      .from('daily_logs')
      .select('user_id, log_date, journal_note, is_note_private, users(display_name)')
      .gte('log_date', twoDaysAgo)
      .in('user_id', relevantUserIds);

    const decryptedNotes: string[] = [];
    if (recentLogs) {
      for (const log of recentLogs) {
        const isPartnerNote = log.user_id !== userData.id;
        // Logic: Add if it's mine OR if it's the partner's and NOT private
        if (log.journal_note && (!isPartnerNote || log.is_note_private === false)) {
          try {
            let bytes: Uint8Array;
            if (typeof log.journal_note === 'string' && log.journal_note.startsWith('\\x')) {
              const hex = log.journal_note.substring(2);
              bytes = new Uint8Array(hex.match(/.{1,2}/g)!.map((byte: string) => parseInt(byte, 16)));
            } else {
              bytes = new Uint8Array(log.journal_note);
            }
            const decrypted = await decryptFernet(bytes, fernetKey!);
            const label = isPartnerNote ? `Partner (${log.users.display_name})` : "User";
            decryptedNotes.push(`${label} [${log.log_date}]: ${decrypted}`);
          } catch (e) { console.error("Decryption error"); }
        }
      }
    }

    // 4. Generate AI Reply
    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    const chatPrompt = `
      You are Zuno, an empathetic AI companion. 
      User: ${userData.display_name}. Insight: ${dailyInsight}
      
      Recent Context (Journal):
      ${decryptedNotes.join('\n')}

      Historical Personal Summary: ${userSummary?.summary_text || 'None'}
      Historical Relationship Summary: ${relSummary?.summary_text || 'None'}

      Current History: ${JSON.stringify(chatHistory)}
      User: "${message}"
      
      Respond warmly as Zuno. Keep it to 2-3 sentences.
    `;

    const result = await model.generateContent(chatPrompt);
    const replyText = result.response.text();

    // 5. UPDATE Summaries for NEXT Context (The Memory Loop)
    const updateSummaryPrompt = (old: string, current: string) => `
      Update the following summary with new insights from this exchange:
      Old Summary: ${old}
      New Interaction: ${current}
      Return only the updated, concise bulleted summary.
    `;

    // Personal Summary Update
    const userUpdateRes = await model.generateContent(updateSummaryPrompt(userSummary?.summary_text || "", `User said: ${message}`));
    await supabaseClient
      .from('ai_summary_user_session')
      .upsert({ 
        user_id: userData.id, 
        summary_text: userUpdateRes.response.text(),
        updated_at: new Date().toISOString()
      }, { onConflict: 'user_id' });

    // Relationship Summary Update
    if (relationshipId) {
      const relUpdateRes = await model.generateContent(updateSummaryPrompt(relSummary?.summary_text || "", `${userData.display_name} said: ${message}`));
      await supabaseClient
        .from('ai_summary_relationship_session')
        .upsert({ 
          relationship_id: relationshipId, 
          summary_text: relUpdateRes.response.text(),
          updated_at: new Date().toISOString()
        }, { onConflict: 'relationship_id' });
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