import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { generateContentWithFallback } from "../_shared/gemini.ts";

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

    // 1. Fetch Last Insight (for caching check)
    const { data: lastInsightData } = await supabaseClient
      .from('daily_cycle_insights')
      .select('*')
      .eq('user_id', userId)
      .maybeSingle();

    if (!force && lastInsightData?.last_generated_at === today && lastInsightData?.energy_category) {
      console.log(`[generate_cycle_insight] Returning cached insight for today`);
      return new Response(JSON.stringify({ 
        insight: lastInsightData.insight_text,
        energy_category: lastInsightData.energy_category,
        energy_message: lastInsightData.energy_message,
        energy_image_name: lastInsightData.energy_image_name
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 2. Fetch User, Cycle Data, and Recent Logs
    const [{ data: userData }, { data: cycleRow }, { data: recentLogs }] = await Promise.all([
      supabaseClient.from('users').select('display_name, gender, user_settings(preferred_language)').eq('id', userId).single(),
      supabaseClient.from('cycle_data').select('*').eq('user_id', userId).maybeSingle(),
      supabaseClient.from('daily_logs').select('mood_emoji, journal_note, context_tags, log_date').eq('user_id', userId).order('log_date', { ascending: false }).limit(5)
    ]);

    if (!userData || userData.gender !== 'Female') {
      throw new Error("Insight generation only available for female users.");
    }

    if (!cycleRow) {
      throw new Error("No cycle data found for user.");
    }

    const language = (userData?.user_settings as any)?.preferred_language || 'English';
    const currentFullTime = new Date().toLocaleString();

    // 3. Calculate Cycle Phase
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

    const prompt = `
      You are Zuno, a warm and perceptive health companion. 
      Today's Date: ${today}.
      User: ${userData.display_name}.
      Cycle: Day ${day} (${phase} phase).
      Recent Logs: ${JSON.stringify(recentLogs || [])}.
      
      [TASK]
      Analyze the user's cycle phase and their recent daily logs to:
      1. Predict their "Energy Level" for today.
      2. Predict potential "Physical Symptoms" and "Moods" they might be experiencing today.
      
      [WEIGHTING RULES]
      1. CRITICAL: The LATEST daily log (if available) should have the highest weight. If it shows low mood or symptoms, the energy level and predictions should reflect that, even if the cycle phase suggests otherwise.
      2. Cycle Day: Use this as the baseline. (e.g., Follicular/Ovulation usually higher energy, Luteal/Menstruation usually lower).
      
      [OPTIONS FOR PREDICTION]
      Physical Symptoms (Choose 1-3):
      - physical:cramps, physical:bloating, physical:headache, physical:back_pain, physical:tender_breasts, physical:fatigue, physical:acne
      
      Moods (Choose 1-3):
      - mood:calm, mood:happy, mood:social, mood:irritable, mood:anxious, mood:sensitive, mood:motivated

      [ENERGY CATEGORIES]
      - Radiant: Very high energy, social, glowing.
      - Sparkling: Creative, inspired, energetic.
      - Balanced: Steady, grounded, productive.
      - Calm: Peaceful, reflective, low-intensity.
      - Unplugged: Very low energy, needs rest, inward-facing.

      [OUTPUT FORMAT - JSON]
      {
        "energy_category": "Predict one of [Radiant, Sparkling, Balanced, Calm, Unplugged]",
        "energy_message": "A warm, 1-sentence insight (max 15 words) explaining why they feel this way based on logs/cycle.",
        "insight": "A general, kind cycle tip for today (max 15 words). NO JARGON (don't say 'Luteal', 'Estrogen', etc).",
        "energy_image_name": "the lowercase category name + .png (e.g., radiant.png)",
        "predicted_physical": ["list", "of", "physical:tags"],
        "predicted_mood": ["list", "of", "mood:tags"]
      }

      Write in ${language}.
    `;

    // 4. Generate Insight with Gemini Fallback Utility
    const result = await generateContentWithFallback(
      Deno.env.get('GEMINI_API_KEY')!,
      prompt,
      { 
        temperature: 0.7,
        responseMimeType: "application/json"
      }
    );

    const responseText = result.response.text();
    const data = JSON.parse(responseText);

    const categoryLower = (data.energy_category || "radiant").toLowerCase();
    const finalImageName = data.energy_image_name || `${categoryLower}.png`;

    console.log(`[generate_cycle_insight] Prediction: ${data.energy_category}, Image: ${finalImageName}, Physical: ${data.predicted_physical}, Mood: ${data.predicted_mood}`);

    // 5. Upsert into Database
    await supabaseClient.from('daily_cycle_insights').upsert({
      user_id: userId,
      insight_text: data.insight,
      energy_category: data.energy_category,
      energy_message: data.energy_message,
      energy_image_name: finalImageName,
      predicted_physical: data.predicted_physical || [],
      predicted_mood: data.predicted_mood || [],
      last_generated_at: today
    });

    return new Response(JSON.stringify({ ...data, energy_image_name: finalImageName }), {
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
