-- Migration to add multi-language support for Daily Chat questions

-- 1. Add translations column to daily_questions
ALTER TABLE public.daily_questions 
ADD COLUMN IF NOT EXISTS translations JSONB DEFAULT '{}'::jsonb;

-- 2. Update assign_daily_questions RPC to return translations
DROP FUNCTION IF EXISTS public.assign_daily_questions(UUID, DATE);

CREATE OR REPLACE FUNCTION public.assign_daily_questions(p_relationship_id UUID, p_date DATE)
RETURNS TABLE (
    couple_daily_question_id UUID,
    question_id UUID,
    question_text TEXT,
    translations JSONB,
    assigned_date DATE
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_count INT;
    v_needed INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM public.couple_daily_questions t
    WHERE t.relationship_id = p_relationship_id AND t.assigned_date = p_date;

    v_needed := 3 - v_count;

    IF v_needed > 0 THEN
        INSERT INTO public.couple_daily_questions (relationship_id, question_id, assigned_date)
        SELECT p_relationship_id, dq.id, p_date
        FROM public.daily_questions dq
        WHERE dq.id NOT IN (
            SELECT cdq.question_id 
            FROM public.couple_daily_questions cdq 
            WHERE cdq.relationship_id = p_relationship_id
        )
        ORDER BY random()
        LIMIT v_needed;
    END IF;

    RETURN QUERY
    SELECT 
        cdq.id AS couple_daily_question_id,
        cdq.question_id AS question_id,
        dq.question_text AS question_text,
        dq.translations AS translations,
        cdq.assigned_date AS assigned_date
    FROM public.couple_daily_questions cdq
    JOIN public.daily_questions dq ON cdq.question_id = dq.id
    WHERE cdq.relationship_id = p_relationship_id AND cdq.assigned_date = p_date;
END;
$$;

-- 3. Seed some initial translations for demonstration
-- Mapping: 'Hindi', 'Malayalam', 'Kannada'
UPDATE public.daily_questions 
SET translations = '{
    "Hindi": "आपकी ऐसी कौन सी छोटी आदत है जिसे मैं मन ही मन बहुत पसंद करता हूँ?",
    "Malayalam": "എന്റെ ഉള്ളിൽ രഹസ്യമായി ഇഷ്ടപ്പെടുന്ന എന്റെ ഒരു ചെറിയ ശീലം എന്താണ്?",
    "Kannada": "ನಾನು ರಹಸ್ಯವಾಗಿ ಪ್ರೀತಿಸುವ ನನ್ನ ಒಂದು ಸಣ್ಣ ಅಭ್ಯಾಸ ಯಾವುದು?"
}'::jsonb 
WHERE question_text = 'What is a small habit of mine that you secretly love?';

UPDATE public.daily_questions 
SET translations = '{
    "Hindi": "अगर हमारे पास असीमित बजट के साथ पूरी तरह से खाली दिन हो, तो हम उसे कैसे बिताएंगे?",
    "Malayalam": "അൺലിമിറ്റഡ് ബജറ്റുള്ള തികച്ചും ഒഴിവുള്ള ഒരു ദിവസം നമുക്കുണ്ടെങ്കിൽ, അത് നമ്മൾ എങ്ങനെ ചെലവഴിക്കും?",
    "Kannada": "ನಮಗೆ ಅನಿಯಮಿತ ಬಜೆಟ್‌ನೊಂದಿಗೆ ಸಂಪೂರ್ಣವಾಗಿ ಬಿಡುವಿನ ದಿನವಿದ್ದರೆ, ನಾವು ಅದನ್ನು ಹೇಗೆ ಕಳೆಯುತ್ತೇವೆ?"
}'::jsonb 
WHERE question_text = 'If we had a completely free day with unlimited budget, how would we spend it?';

UPDATE public.daily_questions 
SET translations = '{
    "Hindi": "आपको कब लगता है कि मेरे द्वारा आपकी सबसे अधिक सराहना की गई है?",
    "Malayalam": "ഞാൻ നിങ്ങളെ ഏറ്റവും കൂടുതൽ നന്ദിപൂർവ്വം ഓർക്കുന്നതായി നിങ്ങൾക്ക് എപ്പോഴാണ് തോന്നുന്നത്?",
    "Kannada": "ನೀವು ನನ್ನಿಂದ ಹೆಚ್ಚು ಮೆಚ್ಚುಗೆ ಪಡೆದಿದ್ದೀರಿ ಎಂದು ನಿಮಗೆ ಯಾವಾಗ ಅನಿಸುತ್ತದೆ?"
}'::jsonb 
WHERE question_text = 'When do you feel the most appreciated by me?';

UPDATE public.daily_questions 
SET translations = '{
    "Hindi": "इस साल एक जोड़े के रूप में हमारे लिए आपका क्या लक्ष्य है?",
    "Malayalam": "ഈ വർഷം ഒരു ദമ്പതികൾ എന്ന നിലയിൽ നമുക്കായി നിങ്ങൾക്ക് എന്ത് ലക്ഷ്യമാണുള്ളത്?",
    "Kannada": "ಈ ವರ್ಷ ನಮಗಾಗಿ ದಂಪತಿಗಳಾಗಿ ನೀವು ಹೊಂದಿರುವ ಒಂದು ಗುರಿ ಏನು?"
}'::jsonb 
WHERE question_text = 'What is a goal you have for us as a couple this year?';
