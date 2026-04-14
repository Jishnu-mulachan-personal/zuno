import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai";
import { generateContentWithFallback } from "../_shared/gemini.ts";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// ── Cycle phase calculator (mirrors Flutter / other edge functions) ──────────
function getPhaseAndDay(row: any): { day: number; phase: string; daysUntilPeriod: number } {
  const lastP    = new Date(row.last_period_date);
  const now      = new Date();
  const lastMid  = new Date(lastP.getFullYear(), lastP.getMonth(), lastP.getDate());
  const todayMid = new Date(now.getFullYear(),   now.getMonth(),   now.getDate());
  const diff     = Math.floor((todayMid.getTime() - lastMid.getTime()) / 86_400_000);
  const length   = row.cycle_length    || 28;
  const dur      = row.period_duration || 5;
  const day      = diff >= 0 ? diff + 1 : 1;

  const nextPeriodDay     = length;                  // cycle day of next period start
  const daysUntilPeriod   = Math.max(0, nextPeriodDay - day);

  let phase = "Luteal";
  if (day > length) {
    phase = "Delayed";
  } else {
    const ov   = length - 14;
    const fwS  = ov - 5;
    const fwE  = ov + 1;
    if      (day <= dur)               phase = "Menstruation";
    else if (day < fwS)                phase = "Follicular";
    else if (day >= fwS && day <= fwE) phase = "Ovulation";
  }

  return { day, phase, daysUntilPeriod };
}

// ── PMS detection ─────────────────────────────────────────────────────────────
function detectPms(phase: string, daysUntilPeriod: number): boolean {
  // True if within 3–5 days of next period OR in Luteal phase
  if (phase === "Luteal") return true;
  if (daysUntilPeriod >= 0 && daysUntilPeriod <= 5) return true;
  return false;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const body       = await req.json().catch(() => ({}));
    const { relationship_id, force } = body;

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')             ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const today = new Date().toISOString().split('T')[0];

    // ── 1. Resolve relationship_id ────────────────────────────────────────
    let relId: string | null = relationship_id ?? null;
    if (!relId) {
      const authHeader = req.headers.get('Authorization');
      if (authHeader) {
        const { data: { user } } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));
        if (user) {
          const { data: u } = await supabase
            .from('users')
            .select('relationship_id')
            .eq('id', user.id)
            .single();
          relId = u?.relationship_id ?? null;
        }
      }
    }
    if (!relId) throw new Error('Missing relationship_id');

    // ── 2. Fetch partners ─────────────────────────────────────────────────
    const { data: members } = await supabase
      .from('users')
      .select('id, display_name, gender')
      .eq('relationship_id', relId);

    if (!members || members.length === 0) throw new Error('No members found in relationship');

    const results = [];

    // ── 3. Generate insight FOR each partner (about their partner) ────────
    // For clarity: we generate an insight ABOUT partner X for partner Y to see.
    for (const partner of members) {
      // Logic: If 'partner' is the one we are generating an insight ABOUT
      
      // Cache check per-partner
      if (!force) {
        const { data: cached } = await supabase
          .from('partner_cycle_insights')
          .select('insight_data, last_generated_at')
          .eq('relationship_id', relId)
          .eq('about_user_id', partner.id)
          .maybeSingle();

        if (cached?.last_generated_at === today) {
          results.push({ about_user_id: partner.id, insight: cached.insight_data });
          continue; 
        }
      }

      console.log(`[generate_partner_insights] Generating for partner: ${partner.display_name} (${partner.gender})`);

      // Common data: Mood logs (last 5 days)
      const fiveDaysAgo = new Date(Date.now() - 5 * 86_400_000).toISOString().split('T')[0];
      const { data: logs } = await supabase
        .from('daily_logs')
        .select('mood_emoji, log_date, context_tags, journal_note, is_note_private')
        .eq('user_id', partner.id)
        .gte('log_date', fiveDaysAgo)
        .order('log_date', { ascending: false });

      const recentMoods    = (logs ?? []).map((l: any) => l.mood_emoji).filter(Boolean);
      const todayLog       = (logs ?? []).find((l: any) => l.log_date === today);
      const moodLogged     = !!todayLog;
      const lastMoodEmoji  = todayLog?.mood_emoji ?? recentMoods[0] ?? null;
      const recentTags     = (logs ?? []).flatMap((l: any) => l.context_tags ?? []);

      let promptContext = "";
      let cycleInfo = { day: 1, phase: 'None', pmsAlert: false, daysUntilPeriod: null as number | null };

      if (partner.gender === 'Female') {
        // Fetch cycle data
        const { data: cycleRow } = await supabase
          .from('cycle_data')
          .select('*')
          .eq('user_id', partner.id)
          .maybeSingle();

        if (cycleRow) {
          const cp = getPhaseAndDay(cycleRow);
          cycleInfo = { 
            day: cp.day, 
            phase: cp.phase, 
            pmsAlert: detectPms(cp.phase, cp.daysUntilPeriod),
            daysUntilPeriod: cp.phase === 'Delayed' ? null : cp.daysUntilPeriod
          };
          
          promptContext = `
[GENDER: FEMALE - CYCLE CONTEXT]
- Cycle Day: ${cycleInfo.day} (Phase: ${cycleInfo.phase === 'Delayed' ? 'Cycle Delayed' : cycleInfo.phase})
- Days until next period: ${cycleInfo.daysUntilPeriod ?? 'Period is already delayed'}
- PMS window active: ${cycleInfo.pmsAlert}
`;
        }
      } else {
        // Male Partner Context: Fetch extra context from Logs & Q&A
        // 1. Journal entries (non-private)
        const journalNotes = (logs ?? [])
          .filter((l: any) => l.journal_note && !l.is_note_private)
          .map((l: any) => l.journal_note)
          .slice(0, 3); // top 3 recent
        
        // 2. Recent question answers
        const { data: qna } = await supabase
          .from('couple_daily_answers')
          .select('answer, couple_daily_questions(daily_questions(question_text))')
          .eq('user_id', partner.id)
          .order('created_at', { ascending: false })
          .limit(3);

        const recentQna = (qna ?? []).map((q: any) => ({
          question: q.couple_daily_questions?.daily_questions?.question_text,
          answer: q.answer
        }));

        promptContext = `
[GENDER: MALE - PSYCHOLOGICAL CONTEXT]
- Recent non-private journal snippets: ${journalNotes.length > 0 ? JSON.stringify(journalNotes) : 'None shared'}
- Recent daily question answers: ${recentQna.length > 0 ? JSON.stringify(recentQna) : 'None answered recently'}
`;
      }

      // ── Generate with Gemini using fallback logic ────────────────────
      const temperature = 0.75;
      const responseMimeType = "application/json";

      const prompt = `
You are Zuno, an empathetic relationship AI. Generate a support guide for a user about their partner, ${partner.display_name} (${partner.gender}).

[CONTEXT]
- Today: ${today}
- Recent moods: ${recentMoods.length > 0 ? recentMoods.join(', ') : 'Not logged recently'}
- Recent activity tags: ${recentTags.length > 0 ? [...new Set(recentTags)].join(', ') : 'None'}
- Mood logged today: ${moodLogged}
${promptContext}

[INSTRUCTIONS]
Generate a JSON object with these exact fields:
- "cycle_day": integer — the current cycle day (use 0 for male)
- "phase": string — one of "Menstruation", "Follicular", "Ovulation", "Luteal", "Delayed", or "None" (for male)
- "pms_alert": boolean — true if PMS window is active (false for male)
- "days_until_period": integer or null — days until next period (null for male or if delayed)
- "summary": string — 2–3 sentences in simple, warm language about ${partner.display_name}'s current state. Address the user.
- "action_items": array of 3–4 strings — specific, practical ways to SUPPORT ${partner.display_name} today.
- "avoid_items": array of 3 strings — specific things to AVOID today.
- "mood_logged": boolean — whether they logged their mood today.
- "last_mood_emoji": string or null — their most recent mood emoji.

[RULES]
- Be warm and specific. 
- If ${partner.gender} is Male, focus on emotional needs, current stress levels (from journals/Q&A), and communication.
- If ${partner.gender} is Female, incorporate cycle phase insights into the advice.
- Output ONLY valid JSON.
`;

      const result = await generateContentWithFallback(
        Deno.env.get('GEMINI_API_KEY')!,
        prompt,
        { temperature, responseMimeType }
      );
      const rawText    = result.response.text().trim();
      let insightData: Record<string, any>;
      try {
        insightData = JSON.parse(rawText);
      } catch (_) {
        const cleaned = rawText.replace(/^```json\s*/i, '').replace(/```$/,'').trim();
        insightData = JSON.parse(cleaned);
      }

      // Force server-side truth
      insightData['cycle_day']         = cycleInfo.day;
      insightData['phase']             = cycleInfo.phase;
      insightData['pms_alert']         = cycleInfo.pmsAlert;
      insightData['days_until_period'] = cycleInfo.daysUntilPeriod;
      insightData['mood_logged']       = moodLogged;
      insightData['last_mood_emoji']   = lastMoodEmoji;

      // Upsert
      await supabase.from('partner_cycle_insights').upsert({
        relationship_id:    relId,
        about_user_id:      partner.id,
        insight_data:       insightData,
        last_generated_at:  today,
      });

      results.push({ about_user_id: partner.id, insight: insightData });
    }

    // Return the insight for the partner of the caller (if possible)
    // Or just all results. Let's try to find the one 'about' the other person.
    let responseData = results;
    const authHeader = req.headers.get('Authorization');
    if (authHeader) {
      const { data: { user } } = await supabase.auth.getUser(authHeader.replace('Bearer ', ''));
      if (user) {
        const otherInsight = results.find(r => r.about_user_id !== user.id);
        if (otherInsight) responseData = otherInsight.insight as any;
      }
    }

    return new Response(JSON.stringify({ insight: responseData }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error(`[generate_partner_insights] FATAL: ${error.message}`);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status:  400,
    });
  }
});

