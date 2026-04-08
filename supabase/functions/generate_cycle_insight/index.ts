import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "https://esm.sh/@google/generative-ai";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const { userId, force } = await req.json();
    console.log(`[generate_cycle_insight] Starting for userId: ${userId}, force: ${force}`);
    if (!userId) throw new Error("Missing userId");

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const today = new Date().toISOString().split('T')[0];

    // 1. Check if we already generated an insight for today (skip if forced)
    if (!force) {
      const { data: existingInsight } = await supabaseClient
        .from('daily_cycle_insights')
        .select('insight_text')
        .eq('user_id', userId)
        .eq('last_generated_at', today)
        .maybeSingle();

      console.log(`[generate_cycle_insight] Existing insight for today: ${existingInsight ? 'FOUND' : 'NOT FOUND'}`);

      if (existingInsight) {
        return new Response(JSON.stringify({ insight: existingInsight.insight_text }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    }

    // 2. Fetch User & Cycle Data
    const { data: userData } = await supabaseClient
      .from('users')
      .select('display_name, gender, user_settings(preferred_language)')
      .eq('id', userId)
      .single();

    console.log(`[generate_cycle_insight] User data: ${JSON.stringify(userData)}`);

    const language = (userData?.user_settings as any)?.preferred_language || 'English';
    console.log(`[generate_cycle_insight] Preferred Language: ${language}`);

    if (!userData || userData.gender !== 'Female') {
      throw new Error("Insight generation only available for female users.");
    }

    const { data: cycleRow } = await supabaseClient
      .from('cycle_data')
      .select('*')
      .eq('user_id', userId)
      .maybeSingle();

    console.log(`[generate_cycle_insight] Cycle row: ${JSON.stringify(cycleRow)}`);

    if (!cycleRow) {
      throw new Error("No cycle data found for user.");
    }

    // 3. Calculate Cycle Phase (Helper consistent with generate_daily_insight)
    const getPhaseAndDay = (row: any) => {
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

    const { day, phase } = getPhaseAndDay(cycleRow);
    console.log(`[generate_cycle_insight] Calculated Day: ${day}, Phase: ${phase}`);

    // 4. Generate Insight with Gemini
    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
    const model = genAI.getGenerativeModel({ 
      model: "gemini-2.5-flash-lite", // Use standard flash model
      generationConfig: { temperature: 0.8 } 
    });

 const prompt = `
      You are Zuno, a warm and perceptive companion. 
      User: ${userData.display_name}.
      Current Status: ${phase === 'Delayed' ? `Cycle is delayed (Day ${day})` : `Day ${day} (${phase} phase)`}.
      
      [GOAL]
      Provide a 2-sentence "energy forecast" that helps ${userData.display_name} feel in sync with her body today.

      [GUIDELINES]
      1. NO JARGON: Never use terms like 'Luteal', 'Estrogen', or 'Menstruation'. Use 'quiet time', 'glow', 'low energy', or 'inner strength'.
      2. PERSPECTIVE: 
         - If ${phase === 'Delayed'}: Be a calming voice. Suggest gentle patience and checking in with how her body feels.
         - If Regular: Match the "vibe" of the phase (e.g., high energy/social vs. cozy/reflective).
      3. EMPATHY: Write as if you are a wise friend who knows her well.

      [TASK]
      Write exactly 2 sentences in ${language} (under 25 words total).
      Sentence 1: Acknowledge her current "inner weather."
      Sentence 2: A tiny, kind suggestion for today.

      CRITICAL: Output ONLY the 2 sentences.
    `;

    const result = await model.generateContent(prompt);
    const insightText = result.response.text().trim().replace(/^"/, "").replace(/"$/, "");
    console.log(`[generate_cycle_insight] Gemini Result: ${insightText}`);

    // 5. Upsert into Database
    await supabaseClient.from('daily_cycle_insights').upsert({
      user_id: userId,
      insight_text: insightText,
      last_generated_at: today
    });

    return new Response(JSON.stringify({ insight: insightText }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error(`[ERROR] ${error.message}`);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
