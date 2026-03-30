import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai";
import { decryptFernet } from "../_shared/fernet.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { phone } = await req.json();
    const fernetKey = Deno.env.get('FERNET_KEY');
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Fetch User Data & Relationship
    const { data: userData } = await supabaseClient
      .from('users')
      .select('id, display_name, relationship_id')
      .eq('phone', phone)
      .single();
    if (!userData) throw new Error("User not found");

    const relId = userData.relationship_id;

    // 2. Fetch Latest Memory Context
    const { data: userSummary } = await supabaseClient
      .from('ai_summary_user_session')
      .select('summary_text')
      .eq('user_id', userData.id)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    let relSummary = null;
    if (relId) {
      const { data: rs } = await supabaseClient
        .from('ai_summary_relationship_session')
        .select('summary_text')
        .eq('relationship_id', relId)
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      relSummary = rs;
    }

    // 3. Fetch Logs for User and Partner
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();
    let relevantIds = [userData.id];

    if (relId) {
      const { data: partners } = await supabaseClient.from('users').select('id').eq('relationship_id', relId);
      if (partners) relevantIds = partners.map(p => p.id);
    }

    const { data: recentLogs } = await supabaseClient
      .from('daily_logs')
      .select('*, users(display_name)')
      .gte('log_date', twoDaysAgo)
      .in('user_id', relevantIds);

    // 4. Decrypt Journal Notes (Precise Mirror of Flutter Logic)
// 4. Decrypt Journal Notes
const journalContext: string[] = [];
const moodContext: string[] = [];

console.log(`[DEBUG] Total logs fetched: ${recentLogs?.length || 0}`);

if (recentLogs && recentLogs.length > 0) {
  for (const log of recentLogs) {
    const isOwner = log.user_id === userData.id;
    const name = log.users?.display_name || "Unknown";
    
    // Always log the mood
    moodContext.push(`${name} felt ${log.mood_emoji || 'neutral'} on ${log.log_date}`);

    console.log(`[DEBUG] Processing log for ${name}. Private: ${log.is_note_private}. Has Note: ${!!log.journal_note}`);

    // Check permissions: (My note) OR (Partner note AND not private)
    const canAccessNote = isOwner || log.is_note_private === false;

    if (log.journal_note && canAccessNote) {
      console.log(`[DEBUG] Entering decryption loop for ${name}...`);
      try {
        let bytesToDecrypt: number[] = [];
        const jn = log.journal_note;

        // LOG THE DATA TYPE: This is critical for debugging
        console.log(`[DEBUG] Raw journal_note type: ${typeof jn}. Value starts with: ${String(jn).substring(0, 10)}`);

        if (typeof jn === 'string' && jn.startsWith('\\x')) {
          // 1. Convert Postgres Hex to ASCII String
          const hexStr = jn.substring(2);
          const asciiBytes = [];
          for (let i = 0; i < hexStr.length; i += 2) {
            asciiBytes.push(parseInt(hexStr.substring(i, i + 2), 16));
          }
          const innerStr = String.fromCharCode(...asciiBytes);
          console.log(`[DEBUG] ASCII string decoded: ${innerStr.substring(0, 15)}...`);

          // 2. Parse the stringified JSON array "[1,2,3]" if it exists
          if (innerStr.trim().startsWith('[')) {
            bytesToDecrypt = JSON.parse(innerStr);
          } else {
            bytesToDecrypt = asciiBytes;
          }
        } else if (Array.isArray(jn)) {
          bytesToDecrypt = jn;
        } else if (typeof jn === 'string') {
          // If it's just a base64 or plain string
          bytesToDecrypt = Array.from(new TextEncoder().encode(jn));
        }

        if (bytesToDecrypt.length > 0) {
          const uint8 = new Uint8Array(bytesToDecrypt);
          console.log(`[DEBUG] Byte length: ${uint8.length}. First byte: ${uint8[0]}`);

          const decrypted = await decryptFernet(uint8, fernetKey!);
          journalContext.push(`${name}'s Journal: ${decrypted}`);
          console.log(`[DEBUG] Decryption Success for ${name}`);
        } else {
          console.log(`[DEBUG] No bytes extracted for ${name}`);
        }

      } catch (e) {
        console.error(`[ERROR] Decryption process failed for ${name}: ${e.message}`);
      }
    } else {
      console.log(`[DEBUG] Access denied or note empty for ${name}. isOwner: ${isOwner}, Private: ${log.is_note_private}`);
    }
  }
}

    // 5. Generate Insight
    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
    const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

    const insightPrompt = `
      You are Zuno, an empathetic AI relationship companion. 
      User: ${userData.display_name}. 
      History: ${userSummary?.summary_text || 'None'}.
      Relationship History: ${relSummary?.summary_text || 'None'}.
      
      Logs & Moods:
      ${moodContext.join('\n')}
      
      Decrypted Journal Insights:
      ${journalContext.join('\n')}

      Write a highly personalized, warm 2-sentence daily insight.
    `;

    const insightResult = await model.generateContent(insightPrompt);
    const insightText = insightResult.response.text();

    // 6. Memory Loop (Updating Tables)
    const updateMemPrompt = (old: string, add: string) => 
      `Update this summary with new insights: "${add}". Old: ${old}. Return concise bullet points.`;

    const newUserMem = await model.generateContent(updateMemPrompt(userSummary?.summary_text || "", insightText));
    
    // User Summary Upsert
    await supabaseClient.from('ai_summary_user_session').upsert({ 
      user_id: userData.id, 
      summary_text: newUserMem.response.text(),
      updated_at: new Date().toISOString()
    }, { onConflict: 'user_id' });

    // Relationship Summary Upsert
    if (relId) {
      const newRelMem = await model.generateContent(updateMemPrompt(relSummary?.summary_text || "", insightText));
      await supabaseClient.from('ai_summary_relationship_session').upsert({ 
        relationship_id: relId, 
        summary_text: newRelMem.response.text(),
        updated_at: new Date().toISOString() 
      }, { onConflict: 'relationship_id' });
    }

    return new Response(JSON.stringify({ insight: insightText }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error(`[FATAL] ${error.message}`);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});