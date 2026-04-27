import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai";
import { decryptFernet } from "../_shared/fernet.ts";
import { generateContentWithFallback } from "../_shared/gemini.ts";

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

    // 2. Fetch Last Insight (for context)
    const { data: lastInsightData } = await supabaseClient
      .from('daily_insights')
      .select('insight_text, last_generated_at')
      .eq('user_id', userData.id)
      .maybeSingle();

    if (!force && lastInsightData?.last_generated_at === new Date().toISOString().split('T')[0]) {
      // Also fetch today's questions to return them
      const { data: existingQuestions } = await supabaseClient
        .from('daily_insight_questions')
        .select('id, question_text, options, selected_option')
        .eq('user_id', userData.id)
        .eq('created_at', lastInsightData.last_generated_at);

      return new Response(JSON.stringify({ 
        insight: lastInsightData.insight_text,
        questions: existingQuestions?.map((q: any) => ({
          id: q.id,
          text: q.question_text,
          options: q.options,
          selected_option: q.selected_option
        })) || []
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const lastInsight = lastInsightData?.insight_text || "No previous insight available.";
    const currentFullTime = new Date().toLocaleString();

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
    const partnerData = relevantUsers.find((u: any) => u.id !== userData.id);
    const hasPartner = !!(userData.relationship_id && partnerData?.id);

    console.log(`[DEBUG] Insight Generation for ${userData.display_name} (ID: ${userData.id}). RelID: ${userData.relationship_id}, Partner Found: ${!!partnerData?.id}`);

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


    // 5. Generate Insight using fallback logic
    const temperature = 0.7;

    const insightPrompt = `
      You are Zuno, an empathetic AI relationship companion. 
      Today's Date: ${currentDate}.
      Current Time: ${currentFullTime}.
      User: ${userData.display_name}. 
      ${hasPartner ? `Partner: ${partnerData.display_name || 'your partner'}.` : ''}
      
      [CONTEXT]
      Last Insight: "${lastInsight}"
      User Status: ${userSummary?.summary_text || 'Stable'} | Moods: ${userMoodContext.length > 0 ? userMoodContext.join(', ') : 'None'} | Journals: ${userJournalContext.length > 0 ? userJournalContext.join(' | ') : 'None'}
      ${hasPartner ? `Partner Status: ${relSummary?.summary_text || 'Stable'} | Moods: ${partnerMoodContext.length > 0 ? partnerMoodContext.join(', ') : 'None'} | Journals: ${partnerJournalContext.length > 0 ? partnerJournalContext.join(' | ') : 'None'}` : ''}
      Biological Energy: ${cycleContext.length > 0 ? cycleContext.join('\n') : 'Typical energy levels.'}

      [GUIDELINES]
      - Speak like a supportive friend. Simple, everyday vocabulary. No therapist jargon.
      ${hasPartner ? '- PARTNER FOCUS: If partner is struggling, acknowledge it.' : '- FOCUS: Focus on the user\'s well-being and personal growth.'}
      - BIOLOGICAL NUANCE: Use cycle data for activity suggestions.

      [TASK]
      Return a JSON object with:
      1. "insight": A warm, 3-sentence insight in ${language}. 
         - Sentence 1: Mirror user's state. 
         - Sentence 2: ${hasPartner ? "Window into partner's vibe." : "A focus on self-care, wellness, or personal growth."}
         - Sentence 3: ${hasPartner ? "Bridge to connection (low-friction action)." : "A gentle, encouraging thought for the day."}
      2. "questions": A list of 1-2 personalized questions in ${language} based on the context above (moods, journals, or special day vibes).
         Each question should have:
         - "text": The question string.
         - "options": A list of 4-5 possible answers. The last option MUST always be a contextual "Not relevant" or "None of these match" choice in ${language}, phrased naturally to fit the question (e.g., "This doesn't describe me today", "Not applicable", etc.).

      Return ONLY the JSON.
    `;
    const insightResult = await generateContentWithFallback(
      Deno.env.get('GEMINI_API_KEY')!,
      insightPrompt,
      { temperature, responseMimeType: 'application/json' }
    );
    
    let generatedData;
    try {
      generatedData = JSON.parse(insightResult.response.text());
    } catch (e) {
      console.error(`[ERROR] JSON parse failed: ${e.message}. Text: ${insightResult.response.text()}`);
      // Fallback for malformed AI output
      generatedData = {
        insight: insightResult.response.text().substring(0, 300),
        questions: []
      };
    }

    const insightText = generatedData.insight;
    const questions = generatedData.questions || [];

    // Persist Insight
    const today = new Date().toISOString().split('T')[0];
    await supabaseClient.from('daily_insights').upsert({
      user_id: userData.id,
      insight_text: insightText,
      last_generated_at: today
    });

    // Clear and Persist Questions
    if (questions.length > 0) {
      // Small cleanup: remove any of today's questions before re-inserting
      await supabaseClient.from('daily_insight_questions')
        .delete()
        .eq('user_id', userData.id)
        .eq('created_at', today);

      const questionRows = questions.map((q: any) => ({
        user_id: userData.id,
        question_text: q.text,
        options: q.options,
        created_at: today
      }));

      const { data: insertedQuestions } = await supabaseClient
        .from('daily_insight_questions')
        .insert(questionRows)
        .select();

      return new Response(JSON.stringify({ 
        insight: insightText,
        questions: insertedQuestions?.map((q: any) => ({
          id: q.id,
          text: q.question_text,
          options: q.options,
          selected_option: q.selected_option
        })) || []
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ 
      insight: insightText,
      questions: []
    }), {
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