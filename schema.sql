-- =====================================================================
--  Wedding RSVP — Supabase schema
--  Run ONCE in Supabase → SQL Editor → New query → paste all → Run.
--  BEFORE RUNNING: change the admin email at the very bottom to your own.
-- =====================================================================

-- ---------- Tables ----------------------------------------------------

-- Who may open admin.html (matched on the email you log in with)
create table if not exists public.admins (
  email text primary key
);

-- One row per invitation (a person, couple or household)
create table if not exists public.invites (
  id               uuid primary key default gen_random_uuid(),
  code             text unique not null,
  household_name   text not null,                  -- "The Naidoo Family", "Thabo & Lerato"
  guest_names      text[] not null default '{}',   -- named adults on the invite
  plus_one_allowed boolean not null default false,
  kids_allowed     boolean not null default true,
  notes            text,                           -- private admin notes
  created_at       timestamptz not null default now()
);

-- One response per invite (re-submitting updates it)
create table if not exists public.rsvps (
  invite_id        uuid primary key references public.invites(id) on delete cascade,
  attending        boolean not null,
  attending_names  text[] not null default '{}',
  plus_one_name    text,
  bringing_kids    boolean not null default false,
  kids_under_10    int not null default 0 check (kids_under_10 between 0 and 20),
  kids_10_plus     int not null default 0 check (kids_10_plus  between 0 and 20),
  kids_names       text,
  dietary          text,
  song_request     text,
  message          text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------- Invite code generator (8 chars, no look-alike letters) -----

create or replace function public.gen_invite_code()
returns text language plpgsql volatile as $$
declare
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  result text;
begin
  loop
    result := '';
    for i in 1..8 loop
      result := result || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.invites where code = result);
  end loop;
  return result;
end $$;

alter table public.invites alter column code set default public.gen_invite_code();

-- ---------- Admin check -----------------------------------------------

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.admins
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

-- ---------- Row Level Security ----------------------------------------
-- Guests never touch the tables directly; they go through the two
-- functions below, which only work with a valid invite code.

alter table public.admins  enable row level security;
alter table public.invites enable row level security;
alter table public.rsvps   enable row level security;

drop policy if exists "admins read admins" on public.admins;
create policy "admins read admins" on public.admins
  for select to authenticated using (public.is_admin());

drop policy if exists "admins manage invites" on public.invites;
create policy "admins manage invites" on public.invites
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admins manage rsvps" on public.rsvps;
create policy "admins manage rsvps" on public.rsvps
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ---------- Guest functions (callable with the public key) ------------

-- Look up an invite by its code, including any earlier response
create or replace function public.get_invite(p_code text)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'code',             i.code,
    'household_name',   i.household_name,
    'guest_names',      i.guest_names,
    'plus_one_allowed', i.plus_one_allowed,
    'kids_allowed',     i.kids_allowed,
    'rsvp', (
      select json_build_object(
        'attending', r.attending, 'attending_names', r.attending_names,
        'plus_one_name', r.plus_one_name, 'bringing_kids', r.bringing_kids,
        'kids_under_10', r.kids_under_10, 'kids_10_plus', r.kids_10_plus,
        'kids_names', r.kids_names, 'dietary', r.dietary,
        'song_request', r.song_request, 'message', r.message,
        'updated_at', r.updated_at)
      from public.rsvps r where r.invite_id = i.id)
  )
  from public.invites i
  where i.code = upper(trim(p_code));
$$;

-- Save (or update) a response
create or replace function public.submit_rsvp(
  p_code text,
  p_attending boolean,
  p_attending_names text[] default '{}',
  p_plus_one_name text default null,
  p_bringing_kids boolean default false,
  p_kids_under_10 int default 0,
  p_kids_10_plus int default 0,
  p_kids_names text default null,
  p_dietary text default null,
  p_song_request text default null,
  p_message text default null
) returns json language plpgsql security definer set search_path = public as $$
declare
  inv public.invites;
  names text[];
  kids boolean;
begin
  select * into inv from public.invites where code = upper(trim(p_code));
  if not found then
    raise exception 'Invite not found';
  end if;

  -- Only names that are actually on the invite are accepted
  select coalesce(array_agg(n), '{}') into names
  from unnest(coalesce(p_attending_names, '{}')) n
  where n = any(inv.guest_names);

  kids := p_attending and inv.kids_allowed and coalesce(p_bringing_kids, false);

  insert into public.rsvps as r (
    invite_id, attending, attending_names, plus_one_name, bringing_kids,
    kids_under_10, kids_10_plus, kids_names, dietary, song_request, message, updated_at)
  values (
    inv.id,
    p_attending,
    case when p_attending then names else '{}' end,
    case when p_attending and inv.plus_one_allowed then left(nullif(trim(p_plus_one_name), ''), 120) end,
    kids,
    case when kids then least(greatest(coalesce(p_kids_under_10, 0), 0), 20) else 0 end,
    case when kids then least(greatest(coalesce(p_kids_10_plus,  0), 0), 20) else 0 end,
    case when kids then left(nullif(trim(p_kids_names), ''), 500) end,
    left(nullif(trim(p_dietary), ''), 1000),
    left(nullif(trim(p_song_request), ''), 300),
    left(nullif(trim(p_message), ''), 2000),
    now())
  on conflict (invite_id) do update set
    attending = excluded.attending,
    attending_names = excluded.attending_names,
    plus_one_name = excluded.plus_one_name,
    bringing_kids = excluded.bringing_kids,
    kids_under_10 = excluded.kids_under_10,
    kids_10_plus = excluded.kids_10_plus,
    kids_names = excluded.kids_names,
    dietary = excluded.dietary,
    song_request = excluded.song_request,
    message = excluded.message,
    updated_at = now();

  return public.get_invite(inv.code);
end $$;

revoke all on function public.get_invite(text) from public;
revoke all on function public.submit_rsvp(text, boolean, text[], text, boolean, int, int, text, text, text, text) from public;
grant execute on function public.get_invite(text) to anon, authenticated;
grant execute on function public.submit_rsvp(text, boolean, text[], text, boolean, int, int, text, text, text, text) to anon, authenticated;

-- ---------- Your admin login ------------------------------------------
-- >>> CHANGE THIS to the personal email you'll log in to admin.html with.
--     Add more lines for anyone else who should see the guest list.
insert into public.admins (email) values ('your.personal@email.com')
on conflict do nothing;

-- ---------- Check it worked -------------------------------------------
-- Expect one row showing your email.
select * from public.admins;
