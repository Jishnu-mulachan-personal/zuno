import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai";

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

    // ── 1. Resolve relationship_id (from body or JWT) ─────────────────────
    let relId: string | null = relationship_id ?? null;

    if (!relId) {
      // Derive from the calling user's JWT
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

    // ── 2. Cache check ────────────────────────────────────────────────────
    if (!force) {
      const { data: cached } = await supabase
        .from('partner_cycle_insights')
        .select('insight_data, last_generated_at')
        .eq('relationship_id', relId)
        .maybeSingle();

      if (cached?.last_generated_at === today) {
        console.log('[generate_partner_insights] Returning cached insight');
        return new Response(JSON.stringify({ insight: cached.insight_data }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    // ── 3. Find the female partner in the relationship ────────────────────
    const { data: members } = await supabase
      .from('users')
      .select('id, display_name, gender')
      .eq('relationship_id', relId);

    const female = (members ?? []).find((u: any) => u.gender === 'Female');
    if (!female) throw new Error('No female partner found in relationship');

    // ── 4. Fetch partner's cycle data ─────────────────────────────────────
    const { data: cycleRow } = await supabase
      .from('cycle_data')
      .select('*')
      .eq('user_id', female.id)
      .maybeSingle();

    if (!cycleRow) throw new Error('No cycle data found for female partner');

    const { day, phase, daysUntilPeriod } = getPhaseAndDay(cycleRow);
    const pmsAlert = detectPms(phase, daysUntilPeriod);

    // ── 5. Fetch recent mood logs (last 5 days) ───────────────────────────
    const fiveDaysAgo = new Date(Date.now() - 5 * 86_400_000).toISOString().split('T')[0];
    const { data: logs } = await supabase
      .from('daily_logs')
      .select('mood_emoji, log_date, context_tags')
      .eq('user_id', female.id)
      .gte('log_date', fiveDaysAgo)
      .order('log_date', { ascending: false });

    const recentMoods    = (logs ?? []).map((l: any) => l.mood_emoji).filter(Boolean);
    const todayLog       = (logs ?? []).find((l: any) => l.log_date === today);
    const moodLogged     = !!todayLog;
    const lastMoodEmoji  = todayLog?.mood_emoji ?? recentMoods[0] ?? null;

    // Symptom context (context_tags on recent logs)
    const recentTags = (logs ?? []).flatMap((l: any) => l.context_tags ?? []);

    // ── 6. Generate structured insight with Gemini ────────────────────────
    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
    const model = genAI.getGenerativeModel({
      model: "gemini-3.1-flash-lite-preview",
      generationConfig: { temperature: 0.75, responseMimeType: "application/json" },
    });

    const prompt = `
You are Zuno, an empathetic relationship AI helping a male partner understand and support his female partner.

[CONTEXT]
- Today: ${today}
- Partner name: ${female.display_name}
- Cycle Day: ${day} (Phase: ${phase === 'Delayed' ? 'Cycle Delayed' : phase})
- Days until next period: ${phase === 'Delayed' ? 'Period is already delayed' : daysUntilPeriod}
- PMS window active: ${pmsAlert}
- Recent moods (last 5 days): ${recentMoods.length > 0 ? recentMoods.join(', ') : 'Not logged recently'}
- Recent activity tags: ${recentTags.length > 0 ? [...new Set(recentTags)].join(', ') : 'None'}
- Mood logged today: ${moodLogged}

[INSTRUCTIONS]
Generate a JSON object with these exact fields:
- "cycle_day": integer — the current cycle day
- "phase": string — one of "Menstruation", "Follicular", "Ovulation", "Luteal", "Delayed"
- "pms_alert": boolean — true if PMS window is active
- "days_until_period": integer or null — days until next period (null if delayed)
- "summary": string — 2–3 sentences in simple, warm language about her current state. Use layman terms. DO NOT mention "Luteal", "estrogen", etc. Address the male partner ("she", "her").
- "action_items": array of 3–4 strings — specific, practical ways the male partner can SUPPORT her today
- "avoid_items": array of 3 strings — specific things the male partner should AVOID today
- "mood_logged": boolean — whether she logged her mood today
- "last_mood_emoji": string or null — her most recent mood emoji if available

[RULES]
- Be warm, specific, and actionable. Not generic.
- action_items should be concrete (e.g., "Offer to cook dinner tonight", not "Be supportive").
- Adapt your tone to the phase: heavy and gentle for Menstruation/Luteal, energetic for Follicular, warm for Ovulation.
- Output ONLY valid JSON. No markdown, no extra text.
`;

    const result     = await model.generateContent(prompt);
    const rawText    = result.response.text().trim();

    let insightData: Record<string, unknown>;
    try {
      insightData = JSON.parse(rawText);
    } catch (_) {
      // Fallback: strip markdown fences if Gemini adds them
      const cleaned = rawText.replace(/^```json\s*/i, '').replace(/```$/,'').trim();
      insightData = JSON.parse(cleaned);
    }

    // Ensure fields populated from server-side truth (not hallucinated)
    insightData['cycle_day']         = day;
    insightData['phase']             = phase;
    insightData['pms_alert']         = pmsAlert;
    insightData['days_until_period'] = phase === 'Delayed' ? null : daysUntilPeriod;
    insightData['mood_logged']       = moodLogged;
    insightData['last_mood_emoji']   = lastMoodEmoji;

    // ── 7. Upsert into partner_cycle_insights ────────────────────────────
    await supabase.from('partner_cycle_insights').upsert({
      relationship_id:    relId,
      insight_data:       insightData,
      last_generated_at:  today,
    });

    console.log(`[generate_partner_insights] Done for relationship ${relId}`);
    return new Response(JSON.stringify({ insight: insightData }), {
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
