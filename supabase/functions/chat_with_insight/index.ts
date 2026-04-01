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
    const { identifier, message, chatHistory, dailyInsight } = await req.json();
    if (!identifier) throw new Error("Unauthorized or missing identifier");

    console.log(`[DEBUG] Chat initiated for identifier: ${identifier}`);

    const fernetKey = Deno.env.get('FERNET_KEY');
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Get User and Relationship Context
    const column = String(identifier).includes('@') ? 'email' : 'phone';
    const { data: userData } = await supabaseClient
      .from('users')
      .select('id, display_name, relationship_id')
      .eq(column, identifier)
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

    // 3. Fetch Logs for User and Partner
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();
    
    let relevantUserIds = [userData.id];
    if (relationshipId) {
      const { data: partners } = await supabaseClient.from('users').select('id').eq('relationship_id', relationshipId);
      relevantUserIds = partners?.map(p => p.id) || [userData.id];
    }

    const { data: recentLogs } = await supabaseClient
      .from('daily_logs')
      .select('user_id, log_date, mood_emoji, journal_note, is_note_private, users(display_name)')
      .gte('log_date', twoDaysAgo)
      .in('user_id', relevantUserIds);

    // 4. Process Logs & Decrypt (with Flutter parity & Privacy Logic)
    const journalContext: string[] = [];
    const moodContext: string[] = [];

    if (recentLogs) {
      for (const log of recentLogs) {
        const isOwner = log.user_id === userData.id;
        const name = log.users?.display_name || "Unknown";

        // Always pass mood/activity to AI
        moodContext.push(`${name} was feeling ${log.mood_emoji || 'neutral'} on ${log.log_date}.`);

        const canAccessNote = isOwner || log.is_note_private === false;

        if (log.journal_note && canAccessNote) {
          try {
            let bytesToDecrypt: number[] = [];
            const jn = log.journal_note;

            if (typeof jn === 'string' && jn.startsWith('\\x')) {
              // 1. Hex to ASCII String
              const hexStr = jn.substring(2);
              const asciiBytes = [];
              for (let i = 0; i < hexStr.length; i += 2) {
                asciiBytes.push(parseInt(hexStr.substring(i, i + 2), 16));
              }
              const innerStr = String.fromCharCode(...asciiBytes);
              
              // 2. Check if stringified JSON array
              if (innerStr.trim().startsWith('[')) {
                bytesToDecrypt = JSON.parse(innerStr);
              } else {
                bytesToDecrypt = asciiBytes;
              }
            } else if (Array.isArray(jn)) {
              bytesToDecrypt = jn;
            } else if (typeof jn === 'string') {
              bytesToDecrypt = Array.from(new TextEncoder().encode(jn));
            }

            if (bytesToDecrypt.length > 0) {
              const uint8 = new Uint8Array(bytesToDecrypt);
              const decrypted = await decryptFernet(uint8, fernetKey!);
              journalContext.push(`${name}'s Journal [${log.log_date}]: ${decrypted}`);
              console.log(`[DEBUG] Decrypted note for ${name}`);
            }
          } catch (e) { 
            console.error(`[ERROR] Decryption error for ${name}: ${e.message}`); 
          }
        } else if (log.journal_note) {
          console.log(`[DEBUG] Skipped private journal note for ${name}`);
        }
      }
    }

    // 5. Generate AI Reply
    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash-lite" });

    const chatPrompt = `
      You are Zuno, an empathetic AI relationship companion. 
      User: ${userData.display_name}. Insight for today: ${dailyInsight}
      
      Recent Moods:
      ${moodContext.join('\n')}

      Recent Context (Journal Notes):
      ${journalContext.join('\n')}

      Historical Personal Summary: ${userSummary?.summary_text || 'None'}
      Historical Relationship Summary: ${relSummary?.summary_text || 'None'}

      Current History: ${JSON.stringify(chatHistory)}
      User: "${message}"
      
      Respond warmly as Zuno. Keep it to 2-3 sentences. Do not mention that some notes are hidden from you.
    `;

    const result = await model.generateContent(chatPrompt);
    const replyText = result.response.text();

    // 6. UPDATE Summaries for NEXT Context (The Memory Loop)
    const updateSummaryPrompt = (old: string, current: string) => `
      Update the following summary with new insights from this exchange. Keep it as a concise bulleted list.
      Old Summary: ${old}
      New Interaction: ${current}
    `;

    try {
      // Personal Summary Update
      const userUpdateRes = await model.generateContent(updateSummaryPrompt(userSummary?.summary_text || "", `User said: "${message}". Zuno replied: "${replyText}"`));
      await supabaseClient
        .from('ai_summary_user_session')
        .upsert({ 
          user_id: userData.id, 
          summary_text: userUpdateRes.response.text(),
          updated_at: new Date().toISOString()
        }, { onConflict: 'user_id' });

      // Relationship Summary Update
      if (relationshipId) {
        const relUpdateRes = await model.generateContent(updateSummaryPrompt(relSummary?.summary_text || "", `${userData.display_name} discussed: "${message}"`));
        await supabaseClient
          .from('ai_summary_relationship_session')
          .upsert({ 
            relationship_id: relationshipId, 
            summary_text: relUpdateRes.response.text(),
            updated_at: new Date().toISOString()
          }, { onConflict: 'relationship_id' });
      }
    } catch (upsertError) {
      console.error(`[DB ERROR] Memory Loop Failed: ${upsertError.message}`);
    }

    return new Response(JSON.stringify({ reply: replyText }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
  } catch (error) {
    console.error(`[FATAL] ${error.message}`);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});