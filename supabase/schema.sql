-- K-Food Guide: event tracking schema (clean reset)
-- Run this once in Supabase → SQL Editor. Safe to re-run: it drops and
-- recreates everything from scratch.

drop view if exists public.stats_summary;
drop view if exists public.find_near_me_by_save_status;
drop view if exists public.food_event_summary;
drop table if exists public.food_events;

create table public.food_events (
  id bigint generated always as identity primary key,
  session_id uuid,
  food_id text not null,
  food_name_ko text,
  event_type text not null check (event_type in ('save', 'unsave', 'find_near_me')),
  was_saved boolean,          -- for 'find_near_me': was the dish saved at click time; for 'save'/'unsave': the resulting state
  created_at timestamptz not null default now()
);

create index food_events_food_id_idx on public.food_events (food_id);
create index food_events_event_type_idx on public.food_events (event_type);
create index food_events_was_saved_idx on public.food_events (was_saved);

-- RLS is on, but with no policies at all, so anon/authenticated get zero
-- access by default. Nothing needs a policy: all writes come from the
-- Vercel server function using the service_role key, which always
-- bypasses RLS regardless of policy state.
alter table public.food_events enable row level security;

-- The exact 4 numbers requested, always computed live off the raw events:
--   saved_count                    → 저장한 음식 수
--   find_near_me_when_saved        → 저장한 음식 중 "근처 맛집 찾기" 클릭 수
--   find_near_me_when_not_saved    → 저장 안 한 음식 중 "근처 맛집 찾기" 클릭 수
--   diff_saved_minus_not_saved     → 위 두 값의 차이
create or replace view public.stats_summary as
select
  (select count(*) from public.food_events where event_type = 'save') as saved_count,
  (select count(*) from public.food_events where event_type = 'find_near_me' and was_saved = true) as find_near_me_when_saved,
  (select count(*) from public.food_events where event_type = 'find_near_me' and was_saved = false) as find_near_me_when_not_saved,
  (select count(*) from public.food_events where event_type = 'find_near_me' and was_saved = true)
  - (select count(*) from public.food_events where event_type = 'find_near_me' and was_saved = false)
    as diff_saved_minus_not_saved;
