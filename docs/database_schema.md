# Zuno – Database Schema (PostgreSQL / Supabase)

## Tables

### `users`
```sql
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT UNIQUE,
    phone           TEXT UNIQUE, 
    display_name    TEXT,
    date_of_birth   DATE,
    occupation      TEXT,
    gender          TEXT,
    relationship_id UUID REFERENCES relationships(id),
    user_status     TEXT DEFAULT 'active',
    created_at      TIMESTAMPTZ DEFAULT now()
);
```

### `relationships`
```sql
CREATE TABLE relationships (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    status              TEXT CHECK (status IN ('dating', 'engaged', 'married', 'trying_for_baby')),
    distance            TEXT CHECK (distance IN ('close', 'moderate', 'distant')),
    anniversary_date    DATE,
    partner_a_id        UUID REFERENCES users(id),
    partner_b_id        UUID REFERENCES users(id),
    game_score          INT DEFAULT 0,
    game_streak         INT DEFAULT 0,
    last_game_date      DATE,
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
    context_tags     TEXT[],
    journal_note     BYTEA,               -- Fernet-encrypted
    is_note_private  BOOLEAN DEFAULT TRUE,
    streak_count     INTEGER DEFAULT 0,
    created_at       TIMESTAMPTZ DEFAULT now()
);
```

### `daily_insights` (AI Engine Output)
```sql
CREATE TABLE daily_insights (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    insight_text      TEXT NOT NULL,
    last_generated_at DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at        TIMESTAMPTZ DEFAULT now()
);
```

### `daily_insight_questions` (Personalized AI Questions)
```sql
CREATE TABLE daily_insight_questions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    question_text   TEXT NOT NULL,
    options         JSONB NOT NULL, -- List of answer choices
    selected_option TEXT,
    created_at      DATE NOT NULL DEFAULT CURRENT_DATE
);
```

### `cycle_data` & `cycle_periods` (Health)
```sql
CREATE TABLE cycle_data (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_period_date DATE,
    cycle_length     INTEGER DEFAULT 28,
    period_duration  INTEGER DEFAULT 5,
    is_tracking      BOOLEAN DEFAULT FALSE,
    updated_at       TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE cycle_periods (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    start_date  DATE NOT NULL,
    end_date    DATE,
    created_at  TIMESTAMPTZ DEFAULT now()
);
```

### `ai_summary_user_session` (Tier 2 Memory)
```sql
CREATE TABLE ai_summary_user_session (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    summary_text TEXT NOT NULL,
    updated_at   TIMESTAMPTZ DEFAULT now()
);
```

### `ai_summary_relationship_session` (Tier 3 Memory)
```sql
CREATE TABLE ai_summary_relationship_session (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_id UUID NOT NULL REFERENCES relationships(id) ON DELETE CASCADE,
    summary_text    TEXT NOT NULL,
    updated_at      TIMESTAMPTZ DEFAULT now()
);
```

### `daily_questions_game` (Game Tables)
```sql
CREATE TABLE daily_questions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    question_text TEXT NOT NULL,
    created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE couple_daily_questions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    relationship_id UUID NOT NULL REFERENCES relationships(id) ON DELETE CASCADE,
    question_id     UUID NOT NULL REFERENCES daily_questions(id) ON DELETE CASCADE,
    assigned_date   DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE TABLE couple_daily_answers (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    couple_daily_question_id UUID NOT NULL REFERENCES couple_daily_questions(id),
    user_id                  UUID NOT NULL REFERENCES users(id),
    answer                   TEXT NOT NULL,
    partner_review_status    TEXT, -- 'understood', 'not_exactly', 'lets_talk'
    partner_review_comment   TEXT
);
```

### `app_versions`
```sql
CREATE TABLE app_versions (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    platform       TEXT NOT NULL, -- 'android', 'ios'
    latest_version TEXT NOT NULL,
    min_version    TEXT NOT NULL,
    update_url     TEXT,
    release_notes  TEXT,
    created_at     TIMESTAMPTZ DEFAULT now()
);
```

---

## Row Level Security (RLS) Policies

### General Rule
Most tables utilize **Isolation by Relationship**. Users can only see data if they belong to the same `relationship_id` as the data owner.

### `daily_logs`
- **Self**: Full access.
- **Partner**: Read access if `is_note_private` is `FALSE`.

### `cycle_data`
- **Owner**: Full access.
- **Partner**: Restricted (Insight engine can access via Service Role, but not direct UI read for privacy).

### `ai_summary_relationship_session`
- **Accessible By**: Any user whose `relationship_id` matches the record.

### `couple_daily_answers`
- Users can view partner's answer once they have submitted their own for that specific `couple_daily_question_id`.

