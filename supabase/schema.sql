-- Reference copy of the schema (applied to Supabase project dgnxbcoxdpdloplkcmzs
-- as migration "overtime_app_schema"). No data here — this repo is public.

create table public.ot_entries (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid() references auth.users(id) on delete cascade,
  date        date not null,
  kind        text not null default 'overtime' check (kind in ('overtime','absence','bonus')),
  minutes     integer not null default 0 check (minutes >= 0 and minutes <= 1440),
  amount      numeric(10,2) check (amount is null or amount >= 0),
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint ot_entries_payload check (
    (kind = 'bonus' and amount is not null) or (kind <> 'bonus' and minutes > 0)
  )
);
create index ot_entries_user_date on public.ot_entries (user_id, date);

create table public.ot_pay_periods (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  effective_from  date not null,
  bank            numeric(10,2) not null default 0,
  cash_base       numeric(10,2) not null default 0,
  ot_rate         numeric(12,6) not null,
  -- Day of the month wages land. The Log summary treats the previous month as
  -- "next to collect" up to and including this day, then switches to this one.
  payday          smallint not null default 5 check (payday between 1 and 28),
  -- Contracted hours a month. Denominator for the Report tab's effective wage
  -- and for the plain hourly rate that OT pay is compared against.
  base_hours      smallint not null default 168 check (base_hours between 1 and 400),
  unique (user_id, effective_from)
);

create table public.ot_share (
  user_id     uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  enabled     boolean not null default false,
  token       text not null default encode(gen_random_bytes(12), 'hex'),
  title       text not null default 'Υπερωρίες',
  date_from   date,
  date_to     date,
  updated_at  timestamptz not null default now()
);
create unique index ot_share_token on public.ot_share (token);

alter table public.ot_entries     enable row level security;
alter table public.ot_pay_periods enable row level security;
alter table public.ot_share       enable row level security;

create policy ot_entries_own on public.ot_entries for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy ot_pay_periods_own on public.ot_pay_periods for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy ot_share_own on public.ot_share for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

create or replace function public.ot_touch() returns trigger language plpgsql
set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;
create trigger ot_entries_touch before update on public.ot_entries for each row execute function public.ot_touch();
create trigger ot_share_touch   before update on public.ot_share   for each row execute function public.ot_touch();

-- The only thing anon can reach: overtime and absence dates + minutes, and only
-- while sharing is on. Dates and durations only — never pay, rates or notes.
-- 'entries' stays overtime-only so an older deployed boss.html keeps working.
create or replace function public.ot_public_report(p_token text)
returns jsonb language sql stable security definer
set search_path = '' as $$
  select case when s.user_id is null then null else jsonb_build_object(
    'title', s.title,
    'from',  s.date_from,
    'to',    s.date_to,
    'entries', coalesce((
      select jsonb_agg(jsonb_build_object('date', e.date, 'minutes', e.minutes) order by e.date, e.created_at)
      from public.ot_entries e
      where e.user_id = s.user_id and e.kind = 'overtime' and e.minutes > 0
        and (s.date_from is null or e.date >= s.date_from)
        and (s.date_to   is null or e.date <= s.date_to)
    ), '[]'::jsonb),
    'absences', coalesce((
      select jsonb_agg(jsonb_build_object('date', e.date, 'minutes', e.minutes) order by e.date, e.created_at)
      from public.ot_entries e
      where e.user_id = s.user_id and e.kind = 'absence' and e.minutes > 0
        and (s.date_from is null or e.date >= s.date_from)
        and (s.date_to   is null or e.date <= s.date_to)
    ), '[]'::jsonb)
  ) end
  from (select 1) one
  left join public.ot_share s on s.enabled and s.token = p_token and length(p_token) >= 16;
$$;
revoke all on function public.ot_public_report(text) from public;
grant execute on function public.ot_public_report(text) to anon, authenticated;
