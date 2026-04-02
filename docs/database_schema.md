# Zuno – Database Schema (PostgreSQL / Supabase)

## Tables

### `users`
```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT UNIQUE, -- Now optional as we use Phone Auth
    phone           TEXT UNIQUE, -- Added for Phone Auth
    display_name    TEXT,
    date_of_birth   DATE,        -- Added from Registration
    occupation      TEXT,        -- Added from Registration
    gender          TEXT,        -- Added from Registration
    relationship_id UUID REFERENCES relationships(id),
    created_at      TIMESTAMPTZ DEFAULT now()
);
```

### `relationships`
```sql
CREATE TABLE relationships (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status              TEXT CHECK (status IN ('dating', 'engaged', 'married', 'trying_for_baby')),
    distance            TEXT CHECK (distance IN ('close', 'moderate', 'distant')), -- Added from Registration
    anniversary_date    DATE, -- Added from Registration
    partner_a_id        UUID REFERENCES users(id),
    partner_b_id        UUID REFERENCES users(id),
    privacy_preference  TEXT CHECK (privacy_preference IN ('private', 'balanced', 'shared')),
    goals               TEXT[],
    created_at          TIMESTAMPTZ DEFAULT now()
);
```

### `daily_logs`
```sql
CREATE TABLE daily_logs (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    log_date         DATE NOT NULL DEFAULT CURRENT_DATE,
    mood_emoji       TEXT,
    connection_felt  BOOLEAN,
    context_tags     TEXT[],
    journal_note     BYTEA,               -- Fernet-encrypted
    is_note_private  BOOLEAN DEFAULT TRUE,
    streak_count     INTEGER DEFAULT 0,
    created_at       TIMESTAMPTZ DEFAULT now()
    -- No UNIQUE constraint: multiple check-ins per day are allowed
);
```

### `cycle_data`
```sql
CREATE TABLE cycle_data (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_period_date DATE,
    cycle_length     INTEGER DEFAULT 28,
    is_tracking      BOOLEAN DEFAULT FALSE,
    updated_at       TIMESTAMPTZ DEFAULT now()
);
-- cycle_data is PRIVATE by default — enforced by RLS
```

### `ai_summaries` (Tier 3 Long-Term Memory)
```sql
CREATE TABLE ai_summaries (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    summary_text  TEXT,
    week_start    DATE,
    generated_at  TIMESTAMPTZ DEFAULT now()
);
```

### `invite_links`
```sql
CREATE TABLE invite_links (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_id UUID NOT NULL REFERENCES relationships(id),
    token           TEXT NOT NULL UNIQUE,
    used            BOOLEAN DEFAULT FALSE,
    expires_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT now()
);
```

---

## Row Level Security (RLS) Policies

```sql
-- Users can only read their own daily logs or their partner's NON-private notes
ALTER TABLE daily_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self_read" ON daily_logs
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY "partner_read" ON daily_logs
    FOR SELECT USING (
        is_note_private = FALSE
        AND user_id IN (
            SELECT CASE
                WHEN partner_a_id = auth.uid() THEN partner_b_id
                WHEN partner_b_id = auth.uid() THEN partner_a_id
            END
            FROM relationships
            WHERE partner_a_id = auth.uid() OR partner_b_id = auth.uid()
        )
    );

-- Cycle data: private to owner only
ALTER TABLE cycle_data ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cycle_owner_only" ON cycle_data
    FOR ALL USING (user_id = auth.uid());

-- INSERT/UPDATE policies for daily_logs
-- Note: These assume you are using Supabase Auth for auth.uid() mapping.
CREATE POLICY "self_insert" ON daily_logs
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "self_update" ON daily_logs
    FOR UPDATE USING (user_id = auth.uid());
```
