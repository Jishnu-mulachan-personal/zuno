-- ─── Shared Posts Table ───────────────────────────────────────────────────────
-- Stores couple timeline posts; each post belongs to a relationship.
-- Both partners in a relationship can see all posts; only authors can edit/delete.

create table if not exists public.shared_posts (
  id             uuid        primary key default gen_random_uuid(),
  relationship_id uuid       not null references public.relationships(id) on delete cascade,
  user_id        uuid        not null references public.users(id) on delete cascade,
  caption        text        not null default '',
  image_url      text,
  context_tags   text[]      not null default '{}',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

-- Index for fast feed queries ordered by time
create index if not exists shared_posts_rel_time_idx
  on public.shared_posts (relationship_id, created_at desc);

-- ─── Row-Level Security ───────────────────────────────────────────────────────
alter table public.shared_posts enable row level security;

-- Helper: get the current user's relationship_id from the users table
create or replace function public.my_relationship_id()
returns uuid language sql stable security definer as $$
  select relationship_id from public.users where id = auth.uid() limit 1;
$$;

-- SELECT: both partners can read all posts in their shared relationship
create policy "Partners can view shared posts"
  on public.shared_posts for select
  using (relationship_id = public.my_relationship_id());

-- INSERT: authenticated users can post to their own relationship
create policy "Partners can insert shared posts"
  on public.shared_posts for insert
  with check (
    user_id = auth.uid()
    and relationship_id = public.my_relationship_id()
  );

-- UPDATE: only the original author can edit their post
create policy "Authors can update own posts"
  on public.shared_posts for update
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- DELETE: only the original author can delete their post
create policy "Authors can delete own posts"
  on public.shared_posts for delete
  using (user_id = auth.uid());

-- Auto-bump updated_at on edit
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists shared_posts_updated_at on public.shared_posts;
create trigger shared_posts_updated_at
  before update on public.shared_posts
  for each row execute procedure public.set_updated_at();

-- ─── Supabase Storage bucket ──────────────────────────────────────────────────
-- Run this in the Supabase dashboard SQL editor OR via the API.
-- The bucket must be created before images can be uploaded.
--
-- insert into storage.buckets (id, name, public)
-- values ('shared-posts', 'shared-posts', false)
-- on conflict (id) do nothing;
--
-- Storage RLS: authenticated users can upload to their own folder
-- and read any object in a shared relationship folder.
--
-- create policy "Authenticated users can upload shared post images"
--   on storage.objects for insert
--   with check (
--     bucket_id = 'shared-posts'
--     and auth.role() = 'authenticated'
--   );
--
-- create policy "Partners can view shared post images"
--   on storage.objects for select
--   using (bucket_id = 'shared-posts' and auth.role() = 'authenticated');
--
-- create policy "Authors can delete own images"
--   on storage.objects for delete
--   using (bucket_id = 'shared-posts' and auth.uid()::text = (storage.foldername(name))[2]);
