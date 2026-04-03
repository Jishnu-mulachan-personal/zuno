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
    const { userId } = await req.json();
    console.log(`[generate_cycle_insight] Starting for userId: ${userId}`);
    if (!userId) throw new Error("Missing userId");

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Check if we already generated an insight for today
    const today = new Date().toISOString().split('T')[0];
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
      let day = diff + 1;
      if (day > length && day > 0) day = (day - 1) % length + 1;
      else if (day <= 0) day = 1;

      let phase = "Luteal";
      const ov = length - 14; 
      const fwS = ov - 5;
      const fwE = ov + 1;
      if (day <= dur) phase = "Menstruation";
      else if (day < fwS) phase = "Follicular";
      else if (day >= fwS && day <= fwE) phase = "Ovulation";
      return { day, phase };
    };

    const { day, phase } = getPhaseAndDay(cycleRow);
    console.log(`[generate_cycle_insight] Calculated Day: ${day}, Phase: ${phase}`);

    // 4. Generate Insight with Gemini
    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
    const model = genAI.getGenerativeModel({ 
      model: "gemini-2.5-flash", // Use standard flash model
      generationConfig: { temperature: 0.8 } 
    });

    const prompt = `
      You are Zuno, a supportive AI health and relationship companion.
      User: ${userData.display_name} (Female)
      Cycle Context: Day ${day} of her cycle, currently in the ${phase} phase.
      
      Task: Write a concise, empowering, and helpful 1-sentence daily cycle insight for ${userData.display_name}.
      The insight should reflect the biological and emotional state typically associated with the ${phase} phase on Day ${day}.
      Focus on self-care, energy levels, or mood. Be warm and empathetic.
      Avoid medical jargon. Keep it under 25 words.
      CRITICAL: The output MUST be written in ${language}.
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
