-- =====================================================================
--  UPDATE 1 — Public RSVP link (no personal invite codes)
--  Run ONCE in Supabase → SQL Editor → New query → paste all → Run.
--  Do NOT re-run schema.sql. Safe to run this file again if needed.
-- =====================================================================

create table if not exists public.public_rsvps (
  id             uuid primary key default gen_random_uuid(),
  phone_key      text unique not null,          -- digits only; one response per phone number
  name           text not null,
  phone          text not null,
  attending      boolean not null,
  adults         int  not null default 0 check (adults between 0 and 10),
  adult_names    text,                          -- the other adults in their group
  bringing_kids  boolean not null default false,
  kids_under_10  int  not null default 0 check (kids_under_10 between 0 and 20),
  kids_10_plus   int  not null default 0 check (kids_10_plus  between 0 and 20),
  kids_names     text,
  dietary        text,
  song_request   text,
  message        text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.public_rsvps enable row level security;

drop policy if exists "admins manage public rsvps" on public.public_rsvps;
create policy "admins manage public rsvps" on public.public_rsvps
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Guests submit through this function only (they can't read the list)
create or replace function public.submit_public_rsvp(
  p_name text,
  p_phone text,
  p_attending boolean,
  p_adults int default 1,
  p_adult_names text default null,
  p_bringing_kids boolean default false,
  p_kids_under_10 int default 0,
  p_kids_10_plus int default 0,
  p_kids_names text default null,
  p_dietary text default null,
  p_song_request text default null,
  p_message text default null
) returns json language plpgsql security definer set search_path = public as $$
declare
  key text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  kids boolean := p_attending and coalesce(p_bringing_kids, false);
  existed boolean;
begin
  if length(trim(coalesce(p_name, ''))) < 2 then raise exception 'Please enter your name'; end if;
  if length(key) < 9 or length(key) > 15 then raise exception 'Please enter a valid phone number'; end if;
  -- treat 0821234567 and +27821234567 as the same number
  if key like '27%' and length(key) = 11 then key := '0' || substr(key, 3); end if;

  select exists (select 1 from public.public_rsvps where phone_key = key) into existed;

  insert into public.public_rsvps as r (
    phone_key, name, phone, attending, adults, adult_names, bringing_kids,
    kids_under_10, kids_10_plus, kids_names, dietary, song_request, message, updated_at)
  values (
    key,
    left(trim(p_name), 120),
    left(trim(p_phone), 30),
    p_attending,
    case when p_attending then least(greatest(coalesce(p_adults, 1), 1), 10) else 0 end,
    case when p_attending then left(nullif(trim(p_adult_names), ''), 500) end,
    kids,
    case when kids then least(greatest(coalesce(p_kids_under_10, 0), 0), 20) else 0 end,
    case when kids then least(greatest(coalesce(p_kids_10_plus,  0), 0), 20) else 0 end,
    case when kids then left(nullif(trim(p_kids_names), ''), 500) end,
    case when p_attending then left(nullif(trim(p_dietary), ''), 1000) end,
    case when p_attending then left(nullif(trim(p_song_request), ''), 300) end,
    left(nullif(trim(p_message), ''), 2000),
    now())
  on conflict (phone_key) do update set
    name = excluded.name, phone = excluded.phone, attending = excluded.attending,
    adults = excluded.adults, adult_names = excluded.adult_names,
    bringing_kids = excluded.bringing_kids, kids_under_10 = excluded.kids_under_10,
    kids_10_plus = excluded.kids_10_plus, kids_names = excluded.kids_names,
    dietary = excluded.dietary, song_request = excluded.song_request,
    message = excluded.message, updated_at = now();

  return json_build_object('updated', existed);
end $$;

revoke all on function public.submit_public_rsvp(text, text, boolean, int, text, boolean, int, int, text, text, text, text) from public;
grant execute on function public.submit_public_rsvp(text, text, boolean, int, text, boolean, int, int, text, text, text, text) to anon, authenticated;

-- Check it worked: expect one row saying public_rsvps.
select 'public_rsvps' as table_ready from information_schema.tables
where table_schema = 'public' and table_name = 'public_rsvps';
