# Fix: Missing Real-Time Refresh for Daily Questions

The user reports that notifications are working, but the UI does not refresh when the partner answers. This is likely because the `couple_daily_answers` table has not been added to the `supabase_realtime` publication, preventing the app from receiving change events.

## Proposed Changes

### Backend (Supabase)

#### [MODIFY] `supabase/migrations/20260409_daily_questions.sql` (or new migration)
- Enable replication for the `couple_daily_answers` table by adding it to the `supabase_realtime` publication.
- Logic:
  ```sql
  alter publication supabase_realtime add table public.couple_daily_answers;
  ```

### Frontend (Flutter)

#### [VERIFY] `lib/features/pairing/daily_questions_state.dart`
- Ensure the `PostgresChangeEvent.all` listener is correctly handling events.
- Add logging to the callback to confirm when an event is received.

## Verification Plan

### Manual Verification
1. Apply the migration to enable replication.
2. Open the "Us" screen on one device.
3. Submit an answer from a different device (Partner).
4. Verify that the first device's UI automatically refreshes without manual interaction.
5. Check debug logs for "Realtime event received" if adding logs.
