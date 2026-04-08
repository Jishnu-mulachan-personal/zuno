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
    const { identifier, force } = await req.json();
    if (!identifier) throw new Error("Missing identifier");
    
    const fernetKey = Deno.env.get('FERNET_KEY');
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const column = String(identifier).includes('@') ? 'email' : 'phone';

    // 1. Fetch User Data & Relationship
    const { data: userData } = await supabaseClient
      .from('users')
      .select('id, display_name, relationship_id, gender, user_settings(preferred_language)')
      .eq(column, identifier)
      .single();
    if (!userData) throw new Error("User not found");

    // 2. Refresh Cache? 
    if (!force) {
      const today = new Date().toISOString().split('T')[0];
      const { data: existingInsight } = await supabaseClient
        .from('daily_insights')
        .select('insight_text')
        .eq('user_id', userData.id)
        .eq('last_generated_at', today)
        .maybeSingle();

      if (existingInsight) {
        return new Response(JSON.stringify({ insight: existingInsight.insight_text }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    const language = (userData?.user_settings as any)?.preferred_language || 'English';

    const relId = userData.relationship_id;

    // 2. Fetch Latest Memory Context (Running DB calls in parallel for speed)
    const [userMemReq, relMemReq, partnersReq] = await Promise.all([
      supabaseClient.from('ai_summary_user_session').select('summary_text').eq('user_id', userData.id).order('created_at', { ascending: false }).limit(1).maybeSingle(),
      relId ? supabaseClient.from('ai_summary_relationship_session').select('summary_text').eq('relationship_id', relId).order('created_at', { ascending: false }).limit(1).maybeSingle() : Promise.resolve({ data: null }),
      relId ? supabaseClient.from('users').select('id, display_name, gender').eq('relationship_id', relId) : Promise.resolve({ data: [userData] })
    ]);

    const userSummary = userMemReq.data;
    const relSummary = relMemReq.data;
    const relevantUsers = partnersReq.data || [userData];
    const relevantIds = relevantUsers.map((u: any) => u.id);
    const partnerData = relevantUsers.find((u: any) => u.id !== userData.id) || {};

    // 3. Fetch logs and cycle info
    const currentDate = new Date().toISOString().split('T')[0];
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();
    
    const [logsReq, cycleReq] = await Promise.all([
      supabaseClient.from('daily_logs').select('*, users(display_name)').gte('log_date', twoDaysAgo).in('user_id', relevantIds),
      supabaseClient.from('cycle_data').select('*').in('user_id', relevantIds)
    ]);

    const recentLogs = logsReq.data;
    const cycleRows = cycleReq.data;

    // 4. Decrypt & Process Context
    const userJournalContext: string[] = [];
    const partnerJournalContext: string[] = [];
    const userMoodContext: string[] = [];
    const partnerMoodContext: string[] = [];
    const cycleContext: string[] = [];

    // Cycle Helper
    const getPhase = (row: any) => {
      // ... (Your exact cycle math logic stays the same here) ...
      const lastP = new Date(row.last_period_date);
      const now = new Date();
      const lastMid = new Date(lastP.getFullYear(), lastP.getMonth(), lastP.getDate());
      const todayMid = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      const diff = Math.floor((todayMid.getTime() - lastMid.getTime()) / (1000 * 60 * 60 * 24));
      const length = row.cycle_length || 28;
      const dur = row.period_duration || 5;
      
      const day = diff >= 0 ? diff + 1 : 1;

      let phase = "Luteal";
      const isPeriodDelayed = day > length;
      
      if (isPeriodDelayed) {
        phase = "Delayed";
      } else {
        const ov = length - 14; 
        const fwS = ov - 5;
        const fwE = ov + 1;
        if (day <= dur) phase = "Menstruation";
        else if (day < fwS) phase = "Follicular";
        else if (day >= fwS && day <= fwE) phase = "Ovulation";
      }
      return { day, phase };
    };

    if (cycleRows && cycleRows.length > 0) {
      for (const row of cycleRows) {
        const u = relevantUsers.find((user: any) => user.id === row.user_id);
        const { day, phase } = getPhase(row);
        cycleContext.push(`${u?.display_name || 'Partner'} is on Day ${day} (${phase} phase).`);
      }
    }

    if (recentLogs && recentLogs.length > 0) {
      for (const log of recentLogs) {
        const isOwner = log.user_id === userData.id;
        const name = log.users?.display_name || "Unknown";
        const moodEntry = `${name} felt ${log.mood_emoji || 'neutral'} on ${log.log_date}`;
        
        if (isOwner) {
          userMoodContext.push(moodEntry);
        } else {
          partnerMoodContext.push(moodEntry);
        }

        const canAccessNote = isOwner || log.is_note_private === false;
        if (log.journal_note && canAccessNote) {
          try {
            // ... (Your exact fernet decryption logic stays the same here) ...
            let bytes: number[] = [];
            const jn = log.journal_note;
            if (typeof jn === 'string' && jn.startsWith('\\x')) {
              const hex = jn.substring(2);
              const b = [];
              for (let i = 0; i < hex.length; i += 2) b.push(parseInt(hex.substring(i, i + 2), 16));
              const inner = String.fromCharCode(...b);
              if (inner.trim().startsWith('[')) bytes = JSON.parse(inner);
              else bytes = b;
            } else if (Array.isArray(jn)) bytes = jn;
            else if (typeof jn === 'string') bytes = Array.from(new TextEncoder().encode(jn));

            if (bytes.length > 0) {
              const dec = await decryptFernet(new Uint8Array(bytes), fernetKey!);
              if (isOwner) {
                userJournalContext.push(`[${log.log_date}] "${dec}"`);
              } else {
                partnerJournalContext.push(`[${log.log_date}] "${dec}"`);
              }
            }
          } catch (e) {
            console.error(`[ERROR] Decryption error: ${e.message}`);
          }
        }
      }
    }

    // 5. Generate Insight
    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
    
    // 🔥 FIX: Set standard Flash model and configure temperature for empathy
    const model = genAI.getGenerativeModel({ 
      model: "gemini-2.5-flash-lite",
      generationConfig: { temperature: 0.7 } 
    });

   const insightPrompt = `
      You are Zuno, an empathetic AI relationship companion. 
      Today's Date: ${currentDate}.
      User: ${userData.display_name}. 
      Partner: ${partnerData.display_name || 'your partner'}.
      
      [CONTEXT]
      User Status: ${userSummary?.summary_text || 'Stable'} | Moods: ${userMoodContext.length > 0 ? userMoodContext.join(', ') : 'None'} | Journals: ${userJournalContext.length > 0 ? userJournalContext.join(' | ') : 'None'}
      Partner Status: ${relSummary?.summary_text || 'Stable'} | Moods: ${partnerMoodContext.length > 0 ? partnerMoodContext.join(', ') : 'None'} | Journals: ${partnerJournalContext.length > 0 ? partnerJournalContext.join(' | ') : 'None'}
      Biological Energy: ${cycleContext.length > 0 ? cycleContext.join('\n') : 'Typical energy levels.'}

      [GUIDELINES]
      1. PARTNER FOCUS: If the partner is struggling (stress, health, cycle, or mood), prioritize acknowledgment of their burden.
      2. SYNERGY: Connect how the user's current energy can best complement the partner's needs.
      3. BIOLOGICAL NUANCE: Use cycle data to suggest "low-battery" vs "high-battery" activities (e.g., nesting vs. going out).
      4. Privacy & Paraphrasing: DO NOT repeat the partner's words or specific journal entries. Interpret the "vibe" (e.g., stress, fatigue, or joy) and speak to that feeling generally.
      5. TEMPORAL WEIGHTING: Give significantly higher weight to the most recent logs (where date matches Today's Date) over older ones when interpreting their current state.

      [TASK]
      Write a warm, 3-sentence insight in ${language}:
      - Sentence 1 (The Mirror): Acknowledge the user's current internal state or energy.
      - Sentence 2 (The Window): Gently highlight what ${partnerData.display_name} might be feeling or carrying right now.
      - Sentence 3 (The Bridge): Suggest a specific, low-friction action to nurture the connection based on the above.

      CRITICAL: Be concise and avoid "bot-speak." Output ONLY the 3 sentences.
    `;
    const insightResult = await model.generateContent(insightPrompt);
    const insightText = insightResult.response.text().trim().replace(/^"/, "").replace(/"$/, "");

    // Persist for "one per day" caching
    const today = new Date().toISOString().split('T')[0];
    await supabaseClient.from('daily_insights').upsert({
      user_id: userData.id,
      insight_text: insightText,
      last_generated_at: today
    });

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