-- ─── Personal Posts Table ───────────────────────────────────────────────────────
-- Stores private user posts; only the owner can access.

create table if not exists public.personal_posts (
  id             uuid        primary key default gen_random_uuid(),
  user_id        uuid        not null references public.users(id) on delete cascade,
  caption        text        not null default '',
  image_url      text,
  context_tags   text[]      not null default '{}',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Index for fast feed queries ordered by time
create index if not exists personal_posts_user_time_idx
  on public.personal_posts (user_id, created_at desc);

-- ─── Row-Level Security ───────────────────────────────────────────────────────
alter table public.personal_posts enable row level security;

-- SELECT: only the owner can view their personal posts
create policy "Users can view own personal posts"
  on public.personal_posts for select
  using (user_id = auth.uid());

-- INSERT: only the owner can insert personal posts
create policy "Users can insert own personal posts"
  on public.personal_posts for insert
  with check (user_id = auth.uid());

-- UPDATE: only the owner can update their personal posts
create policy "Users can update own personal posts"
  on public.personal_posts for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- DELETE: only the owner can delete their personal posts
create policy "Users can delete own personal posts"
  on public.personal_posts for delete
  using (user_id = auth.uid());

-- Auto-bump updated_at on edit
create trigger personal_posts_updated_at
  before update on public.personal_posts
  for each row execute procedure public.set_updated_at();

-- ─── Supabase Storage bucket ──────────────────────────────────────────────────
-- The bucket `personal-posts` must be created manually or via the API.
-- bucket_id: 'personal-posts', public: false

-- RLS for the personal-posts bucket in storage.objects
create policy "Users can view own personal posts images"
  on storage.objects for select
  using (bucket_id = 'personal-posts' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can upload own personal posts images"
  on storage.objects for insert
  with check (bucket_id = 'personal-posts' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can update own personal posts images"
  on storage.objects for update
  using (bucket_id = 'personal-posts' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "Users can delete own personal posts images"
  on storage.objects for delete
  using (bucket_id = 'personal-posts' and (storage.foldername(name))[1] = auth.uid()::text);
