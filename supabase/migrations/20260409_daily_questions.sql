-- Migration for Daily Questions Game

-- 1. Alter Relationships table for tracking game score and streak
ALTER TABLE public.relationships
ADD COLUMN IF NOT EXISTS game_score INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS game_streak INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS last_game_date DATE;

-- 2. Daily Questions Master Table
CREATE TABLE IF NOT EXISTS public.daily_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_text TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Couple Assigned Questions
CREATE TABLE IF NOT EXISTS public.couple_daily_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_id UUID NOT NULL REFERENCES public.relationships(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES public.daily_questions(id) ON DELETE CASCADE,
    assigned_date DATE NOT NULL DEFAULT (CURRENT_DATE AT TIME ZONE 'UTC'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(relationship_id, question_id)
);

-- Index to quickly get a relationship's daily questions for a given date
CREATE INDEX IF NOT EXISTS couple_daily_questions_rel_date_idx 
    ON public.couple_daily_questions(relationship_id, assigned_date);

-- 4. Couple Daily Answers
CREATE TABLE IF NOT EXISTS public.couple_daily_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_daily_question_id UUID NOT NULL REFERENCES public.couple_daily_questions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    answer TEXT NOT NULL,
    partner_review_status TEXT CHECK (partner_review_status IN ('understood', 'not_exactly', 'lets_talk')),
    partner_review_comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(couple_daily_question_id, user_id)
);

-- 5. RPC to assign daily questions
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

-- 6. RPC to submit a partner's review and update streak/score
CREATE OR REPLACE FUNCTION public.submit_partner_review(
    p_answer_id UUID, 
    p_relationship_id UUID, 
    p_review_status TEXT, 
    p_review_comment TEXT,
    p_local_date DATE
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_points INT := 0;
    v_current_streak INT;
    v_last_game_date DATE;
BEGIN
    -- Ensure authorized
    IF public.my_relationship_id() != p_relationship_id THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    -- Calculate points
    IF p_review_status = 'understood' THEN
        v_points := 10;
    ELSIF p_review_status = 'not_exactly' THEN
        v_points := 5;
    ELSIF p_review_status = 'lets_talk' THEN
        v_points := 0;
    ELSE
        RAISE EXCEPTION 'Invalid review status';
    END IF;

    -- Update the partner's answer with the review
    UPDATE public.couple_daily_answers
    SET partner_review_status = p_review_status,
        partner_review_comment = p_review_comment
    WHERE id = p_answer_id;

    -- Fetch current streak info
    SELECT game_streak, last_game_date INTO v_current_streak, v_last_game_date
    FROM public.relationships
    WHERE id = p_relationship_id;

    -- Streak logic: 
    IF v_last_game_date = p_local_date THEN
        -- Just update score
        UPDATE public.relationships
        SET game_score = COALESCE(game_score, 0) + v_points
        WHERE id = p_relationship_id;
    ELSIF v_last_game_date = p_local_date - interval '1 day' THEN
        -- Back to back, increment streak
        UPDATE public.relationships
        SET game_score = COALESCE(game_score, 0) + v_points,
            game_streak = COALESCE(v_current_streak, 0) + 1,
            last_game_date = p_local_date
        WHERE id = p_relationship_id;
    ELSE
        -- Missed a day or first time playing
        UPDATE public.relationships
        SET game_score = COALESCE(game_score, 0) + v_points,
            game_streak = 1,
            last_game_date = p_local_date
        WHERE id = p_relationship_id;
    END IF;

END;
$$;

-- 7. RLS Policies
ALTER TABLE public.daily_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read daily_questions" ON public.daily_questions FOR SELECT USING (true);

ALTER TABLE public.couple_daily_questions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Partners can read their couple_daily_questions" ON public.couple_daily_questions FOR SELECT USING (relationship_id = public.my_relationship_id());

ALTER TABLE public.couple_daily_answers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Partners can view shared answers" ON public.couple_daily_answers FOR SELECT 
    USING (couple_daily_question_id IN (SELECT id FROM public.couple_daily_questions WHERE relationship_id = public.my_relationship_id()));
CREATE POLICY "Partners can insert answers" ON public.couple_daily_answers FOR INSERT 
    WITH CHECK (user_id = auth.uid() AND couple_daily_question_id IN (SELECT id FROM public.couple_daily_questions WHERE relationship_id = public.my_relationship_id()));

CREATE POLICY "Users can edit own answer" ON public.couple_daily_answers FOR UPDATE 
    USING (user_id = auth.uid()) WITH CHECK(user_id = auth.uid());

-- 8. Seed Initial Questions
INSERT INTO public.daily_questions (question_text) VALUES 
('What is a small habit of mine that you secretly love?'),
('If we had a completely free day with unlimited budget, how would we spend it?'),
('When do you feel the most appreciated by me?'),
('What is a goal you have for us as a couple this year?'),
('What’s a movie or show you think perfectly describes our dynamic?'),
('What was your first impression of me, and how has it changed?'),
('If you could relive one of our dates, which would it be and why?'),
('What is one thing you’d like to do differently in our routine?'),
('When we argue, what’s something I can do to make it easier for us to reconnect?'),
('What’s a childhood memory that still brings you joy today?'),
('If we were to open a business together, what would it be?'),
('What’s a physical touch or gesture that makes you feel instantly comforted?'),
('What is one fear you have that you rarely talk about?'),
('How do you prefer to receive affection when you’re stressed?'),
('What’s an inside joke of ours that still cracks you up?');
