-- K-Food Guide: event tracking schema
-- Run this once in Supabase → SQL Editor.

create table if not exists public.food_events (
  id bigint generated always as identity primary key,
  session_id uuid not null,
  food_id text not null,
  food_name_ko text,
  event_type text not null check (event_type in ('search', 'save', 'unsave', 'find_near_me')),
  was_saved boolean,          -- meaningful for 'find_near_me' (and 'save'/'unsave'): was the dish saved at that moment?
  lang text,                  -- ui language active when the event fired (ko/en/zh)
  query text,                 -- raw search text, only set for 'search' events
  created_at timestamptz not null default now()
);

create index if not exists food_events_food_id_idx on public.food_events (food_id);
create index if not exists food_events_event_type_idx on public.food_events (event_type);
create index if not exists food_events_was_saved_idx on public.food_events (was_saved);
create index if not exists food_events_created_at_idx on public.food_events (created_at);

alter table public.food_events enable row level security;

-- The app writes with the public (anon/publishable) key, so it only needs
-- INSERT. Targeting "public" rather than "anon" avoids depending on which
-- Postgres role a given key format happens to map to. Reads/analysis
-- happen from the Supabase SQL editor (an admin role that bypasses RLS
-- entirely), so no public SELECT policy is added here.
drop policy if exists "anon can insert food_events" on public.food_events;
drop policy if exists "anyone can insert food_events" on public.food_events;
create policy "anyone can insert food_events"
  on public.food_events
  for insert
  to public
  with check (true);

-- Per-food, per-event-type counts (covers "검색한 음식" / "저장한 음식" volumes).
create or replace view public.food_event_summary as
select
  food_id,
  event_type,
  was_saved,
  count(*) as event_count
from public.food_events
group by food_id, event_type, was_saved
order by food_id, event_type, was_saved;

-- The specific comparison requested: among "find near me" clicks, how do
-- clicks on already-saved dishes differ from clicks on not-yet-saved dishes.
create or replace view public.find_near_me_by_save_status as
select
  food_id,
  count(*) filter (where was_saved = true)  as clicks_when_saved,
  count(*) filter (where was_saved = false) as clicks_when_not_saved,
  count(*) filter (where was_saved = true) - count(*) filter (where was_saved = false)
    as diff_saved_minus_not_saved
from public.food_events
where event_type = 'find_near_me'
group by food_id
order by food_id;
