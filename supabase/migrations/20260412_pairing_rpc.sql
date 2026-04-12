-- Migration to update pairing RPC for persistent status
-- This allows users to pair while maintaining their preferred status (e.g. married).

CREATE OR REPLACE FUNCTION public.claim_pair_invite(invite_token text, p_status text DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with elevated privileges
SET search_path = public
AS $$
DECLARE
    v_invite_id uuid;
    v_creator_id uuid;
    v_claimer_id uuid;
    v_relationship_id uuid;
    v_already_used boolean;
    v_expires_at timestamptz;
    v_final_status text;
    v_creator_status text;
BEGIN
    -- 1. Get current authenticated user
    v_claimer_id := auth.uid();
    IF v_claimer_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Not authenticated');
    END IF;

    -- 2. Lookup invite
    SELECT id, created_by, used, expires_at 
    INTO v_invite_id, v_creator_id, v_already_used, v_expires_at
    FROM public.partner_invites
    WHERE token = invite_token
    LIMIT 1;

    -- 3. Validation
    IF v_invite_id IS NULL THEN
        RETURN json_build_object('success', false, 'message', 'Invite not found');
    END IF;

    IF v_already_used OR v_expires_at < now() THEN
        RETURN json_build_object('success', false, 'message', 'Invite already used or expired');
    END IF;

    IF v_claimer_id = v_creator_id THEN
        RETURN json_build_object('success', false, 'message', 'You cannot pair with yourself');
    END IF;

    -- 4. Determine final status
    -- Priority: passed p_status -> creator's current status -> default 'dating'
    SELECT relationship_status INTO v_creator_status FROM public.users WHERE id = v_creator_id;
    v_final_status := COALESCE(p_status, v_creator_status, 'dating');

    -- 5. Find or Create Relationship
    SELECT relationship_id INTO v_relationship_id
    FROM public.users
    WHERE id = v_creator_id;

    IF v_relationship_id IS NOT NULL THEN
        -- Link claimer to creator's existing relationship
        UPDATE public.relationships
        SET partner_b_id = v_claimer_id,
            status = v_final_status
        WHERE id = v_relationship_id;
    ELSE
        -- Create new relationship row
        INSERT INTO public.relationships (partner_a_id, partner_b_id, status)
        VALUES (v_creator_id, v_claimer_id, v_final_status)
        RETURNING id INTO v_relationship_id;
    END IF;

    -- 6. Link both users to the relationship and update their profile status
    UPDATE public.users
    SET relationship_id = v_relationship_id,
        relationship_status = v_final_status
    WHERE id IN (v_creator_id, v_claimer_id);

    -- 7. Mark invite as used
    UPDATE public.partner_invites
    SET used = true,
        used_by = v_claimer_id
    WHERE id = v_invite_id;

    RETURN json_build_object(
        'success', true, 
        'message', 'Paired successfully!', 
        'relationship_id', v_relationship_id,
        'status', v_final_status
    );
END;
$$;
