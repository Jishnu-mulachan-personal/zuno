# Couple Daily Questions Game

The goal is to build a "Daily Questions Game" feature in the "Us" tab where couples answer 3 daily questions. Their answers are compared to generate a result ("Matched 💚", "Not Matched 🤔", "Let’s talk about this 💬").

## Proposed Workflow

1. Both partners answer the daily question independently.
2. Once both have submitted, the app reveals both answers.
3. Each partner reviews the other's answer and marks it with one of three statuses:
   - 💚 "You understood me"
   - 🤔 "Not exactly"
   - 💬 "Let’s talk"
4. After marking, the reviewing partner can leave an optional short comment (e.g., "I actually meant this...").
5. The daily score is updated based on these reviews.

## Proposed Changes

---

### Backend (Supabase)

We need to store the question pool, daily assignments per relationship, and the answers.

#### [NEW] `supabase/migrations/20260409_daily_questions.sql`

- **Tables/Columns**:
  - `daily_questions`: `id`, `question_text`, `created_at`.
  - `couple_daily_questions`: `id`, `relationship_id`, `question_id`, `assigned_date`. Unique constraint on `(relationship_id, question_id)` ensures no repeats.
  - `couple_daily_answers`: 
    - `id`, `couple_daily_question_id`, `user_id`, `answer`
    - `partner_review_status` (string/enum: 'understood', 'not_exactly', 'lets_talk')
    - `partner_review_comment` (text, nullable)
    - `created_at`
  - **Alter Table `relationships`**:
    - Add `game_score` (INT default 0).
    - Add `game_streak` (INT default 0).
    - Add `last_game_date` (DATE).
- **RPC `assign_daily_questions`**:
  - Takes relationship ID and local date.
  - Returns 3 assigned questions for that date. If less than 3 exist, it randomly selects from `daily_questions` that haven't been assigned to the relationship yet, inserts them, and returns the list.
- **RPC `submit_partner_review`**:
  - Allows updating an answer's review status.
  - Automatically calculates score based on the review (e.g., 💚 = +10 pts, 🤔 = +5 pts, 💬 = 0 pts).
  - Automatically handles Streak logic: increments `game_streak` if played yesterday, resets to 1 if missed a day, and updates `last_game_date`.
- **Row-Level Security (RLS)**:
  - Add policies ensuring users can only read/write answers for their relationship.

---

### Frontend (Flutter)

#### [MODIFY] `lib/features/pairing/us_screen.dart`

- Inject the `DailyQuestionsCard` widget near the top of the paired state (e.g., right under the `_PairedHeader`).
- **Score & Streak Widgets**: Display these metrics elegantly (e.g., as chips/badges) above the Daily Questions or integrated directly into the `DailyQuestionsCard` header. Both partners can see their shared couples game score and blazing streak icon (🔥).

#### [NEW] `lib/features/pairing/daily_questions_service.dart` (or State/Notifier)

- Create Riverpod providers and methods to:
  - Fetch today's questions (via the `assign_daily_questions` RPC).
  - Submit own answer.
  - Submit review of partner's answer via the new RPC.
  - Listen to real-time changes or refresh to get the partner's answer and review, plus updated score/streak.

#### [NEW] `lib/features/pairing/widgets/daily_questions_card.dart`

- **UI Logic**:
  - Show a list/carousel of 3 questions.
  - **State 1 (Unanswered)**: Input field and submit button.
  - **State 2 (Waiting)**: If user answered but partner hasn't, show "Waiting for partner...".
  - **State 3 (Ready for Review)**: If both answered but user hasn't reviewed partner's answer, show partner's answer with review buttons (💚 "You understood me", 🤔 "Not exactly", 💬 "Let's talk") and an optional text input for a comment.
  - **State 4 (Completed)**: Display both answers, the assigned reviews, and the optional text comments.

## Open Questions

- **Review Visibility**: Do we want the partner to instantly see the review, or does it only reveal when both have finished reviewing? (I assume instantly is fine).

## Verification Plan

### Automated Tests
- Run SQL migrations to seed questions and create tables/RPC.

### Manual Verification
- Log in as User A, navigate to "Us" tab, see 3 questions.
- Answer a question. See "Waiting for partner".
- Log in as User B. Answer the same question. 
- See User A's answer and review UI. Tap 💚 "You understood me" and leave a small comment. 
- Log in as User A. See User B's review and comment on User A's answer.
- Verify Score and Streak widgets reflect accurately on both clients.
