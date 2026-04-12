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
    const { relationship_id } = await req.json();
    if (!relationship_id) throw new Error("Missing relationship_id");
    
    const fernetKey = Deno.env.get('FERNET_KEY');
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // 1. Fetch Relationship & Partners
    const { data: relationshipData, error: relError } = await supabaseClient
      .from('relationships')
      .select('id')
      .eq('id', relationship_id)
      .single();
    
    if (relError || !relationshipData) throw new Error(`Relationship not found: ${relationship_id}`);

    const { data: partners, error: partnersError } = await supabaseClient
      .from('users')
      .select('id, display_name, user_settings(preferred_language)')
      .eq('relationship_id', relationship_id);

    if (partnersError || !partners || partners.length < 2) {
      throw new Error("Could not find both partners for the relationship.");
    }

    const partnerIds = partners.map(p => p.id);
    const partnerNames = partners.reduce((acc, p) => ({ ...acc, [p.id]: p.display_name }), {} as Record<string, string>);
    const language = (partners?.[0] as any)?.user_settings?.preferred_language || 'English';

    // 2. Define Date Range (Last 7 Days)
    const now = new Date();
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000).toISOString();

    // 3. Fetch Data in Parallel
    const [logsReq, answersReq, cyclesReq, periodsReq, postsReq] = await Promise.all([
      // Fetch daily logs (moods & journals)
      supabaseClient
        .from('daily_logs')
        .select('*')
        .in('user_id', partnerIds)
        .gte('log_date', sevenDaysAgo.split('T')[0])
        .order('log_date', { ascending: true }),
      
      // Fetch daily question answers
      supabaseClient
        .from('couple_daily_answers')
        .select('*, couple_daily_questions(assigned_date, daily_questions(question_text))')
        .in('user_id', partnerIds)
        .gte('created_at', sevenDaysAgo)
        .order('created_at', { ascending: true }),

      // Fetch cycle configuration
      supabaseClient
        .from('cycle_data')
        .select('*')
        .in('user_id', partnerIds),

      // Fetch historical periods
      supabaseClient
        .from('cycle_periods')
        .select('*')
        .in('user_id', partnerIds)
        .gte('start_date', sevenDaysAgo.split('T')[0]),

      // Fetch shared posts for context
      supabaseClient
        .from('shared_posts')
        .select('*')
        .eq('relationship_id', relationship_id)
        .gte('created_at', sevenDaysAgo)
        .order('created_at', { ascending: true })
    ]);

    if (logsReq.error) throw logsReq.error;
    if (answersReq.error) throw answersReq.error;

    const logs = logsReq.data || [];
    const answers = answersReq.data || [];
    const cycleData = cyclesReq.data || [];
    const cyclePeriods = periodsReq.data || [];
    const sharedPosts = postsReq.data || [];

    // 4. Process Logs (Decrypt Journals & Structure Moods)
    const processedLogs = await Promise.all(logs.map(async (log) => {
      let decryptedNote = null;
      if (log.journal_note) {
        try {
          let bytes: number[] = [];
          const jn = log.journal_note;
          if (typeof jn === 'string' && jn.startsWith('\\x')) {
            const hex = jn.substring(2);
            for (let i = 0; i < hex.length; i += 2) bytes.push(parseInt(hex.substring(i, i + 2), 16));
          } else if (Array.isArray(jn)) bytes = jn;
          else if (typeof jn === 'string') bytes = Array.from(new TextEncoder().encode(jn));

          if (bytes.length > 0 && fernetKey) {
            decryptedNote = await decryptFernet(new Uint8Array(bytes), fernetKey);
          }
        } catch (e) {
          console.error(`[DECRYPTION ERROR] for log ${log.id}:`, e.message);
        }
      }
      return {
        date: log.log_date,
        user: partnerNames[log.user_id] || "Partner",
        mood: log.mood_emoji || "Neutral",
        journal_note: decryptedNote,
        is_private: log.is_note_private
      };
    }));

    // 5. Structure Q&A Data
    const processedAnswers = answers.map((ans: any) => ({
      date: ans.couple_daily_questions?.assigned_date,
      user: partnerNames[ans.user_id] || "Partner",
      question: ans.couple_daily_questions?.daily_questions?.question_text,
      answer: ans.answer,
      review_status: ans.partner_review_status
    }));

    // 6. Generate Weekly Insight with Gemini
    const genAI = new GoogleGenerativeAI(Deno.env.get('GEMINI_API_KEY')!);
    const model = genAI.getGenerativeModel({ 
      model: "gemini-3.1-flash-lite-preview", // Using latest stable flash for high quality
      generationConfig: { 
        temperature: 0.7,
        responseMimeType: "application/json"
      } 
    });

    const systemPrompt = `
      You are Zuno, a premium relationship psychologist and AI companion. 
      Analyze the couple's data from the last 7 days and generate a Weekly Relationship Report.
      
      [DATA PROVIDED]
      - Daily Moods & Journals: ${JSON.stringify(processedLogs)}
      - Daily Question Answers: ${JSON.stringify(processedAnswers)}
      - Cycle Info: ${JSON.stringify(cycleData)}
      - Recent Period Entries: ${JSON.stringify(cyclePeriods)}
      - Shared Moments (Timeline): ${JSON.stringify(sharedPosts.map((p: any) => ({ caption: p.caption, date: p.created_at })))}

      [STRICT PRIVACY DIRECTIVE]
      NEVER repeat private journal content verbatim. Use it to understand the core sentiment and translate it into supportive observations.

      [OUTPUT FORMAT]
      Return a JSON object with exactly these fields:
      1. "pattern_text": (LEGACY) General week observation.
      2. "pattern_data": Array of 7 objects. "day" (3-letter name), "partnerA" (score 1-5), "partnerB" (score 1-5).
      3. "alignment_text": (LEGACY) Brief Q&A alignment summary.
      4. "alignment_data": Object with Support, Connection, Energy, Romance scores (1-5) for both partners.
      5. "theme_text": The overall emotional theme of the week.
      6. "mood_harmony_insight": A warm, simple observation about their synced moods. Mention specific days if relevant (e.g. "peaceful peak on Tuesday").
      7. "vibe_title": A short, evocative title for their current shared state (e.g., "Reflective & Quiet", "High Energy & Fun").
      8. "vibe_text": A paragraph describing the energy between them.
      9. "recommendation": A specific weekend activity suggestion based on their vibe.
      10. "highlights": An object containing:
          - "cycle_note": If a period was recorded, mention it naturally (e.g., "Luteal phase support needed" or "Period recorded Mon-Wed").
          - "partner_peaks": Array of Object { "name": string, "peak_moment": string } identifying the happiest moment for each partner.
          - "looking_ahead": A note about a future plan identified from their context (shared posts or answers).
      
      Tone: Warm, empathetic, premium, supportive. Use extremely simple, clear, and direct language that anyone can easily read. Avoid complex words or poetic metaphors.
      
      [OUTPUT LANGUAGE]
      IMPORTANT: You must write the entire report (all text fields in JSON) in ${language}.
    `;

    const result = await model.generateContent(systemPrompt);
    const responseText = result.response.text();
    const insights = JSON.parse(responseText);

    // 7. Store in Database
    const { error: insertError } = await supabaseClient
      .from('weekly_insights')
      .insert({
        relationship_id,
        pattern_text: insights.pattern_text,
        pattern_data: insights.pattern_data,
        alignment_text: insights.alignment_text,
        alignment_data: insights.alignment_data,
        theme_text: insights.theme_text,
        mood_harmony_insight: insights.mood_harmony_insight,
        vibe_title: insights.vibe_title,
        vibe_text: insights.vibe_text,
        recommendation: insights.recommendation,
        highlights: insights.highlights
      });

    if (insertError) throw insertError;

    return new Response(JSON.stringify({ success: true, insights }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error(`[FATAL ERROR] ${error.message}`);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});
