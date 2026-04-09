-- Fix ambiguous column reference in assign_daily_questions RPC
CREATE OR REPLACE FUNCTION public.assign_daily_questions(p_relationship_id UUID, p_date DATE)
RETURNS TABLE (
    couple_daily_question_id UUID,
    question_id UUID,
    question_text TEXT,
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
        cdq.assigned_date AS assigned_date
    FROM public.couple_daily_questions cdq
    JOIN public.daily_questions dq ON cdq.question_id = dq.id
    WHERE cdq.relationship_id = p_relationship_id AND cdq.assigned_date = p_date;
END;
$$;
