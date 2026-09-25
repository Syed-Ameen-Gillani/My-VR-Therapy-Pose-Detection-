-- Run once in Supabase SQL Editor before saving Android camera sessions.
-- Additive migration for earlier FYP databases; retains existing records.
begin;
alter table public.sessions add column if not exists plan_id text references public.plans(id);
alter table public.sessions add column if not exists plan_version integer;
alter table public.sessions add column if not exists range_degrees numeric;
alter table public.sessions add column if not exists reviewed boolean not null default false;
alter table public.sessions add column if not exists analysis_payload jsonb not null default '{}'::jsonb;
alter table public.sessions add column if not exists created_at timestamptz not null default now();
alter table public.sessions add column if not exists updated_at timestamptz not null default now();
alter table public.session_reviews add column if not exists session_id text;
alter table public.session_reviews add column if not exists therapist_id uuid;
alter table public.session_reviews add column if not exists note text;
alter table public.session_reviews add column if not exists therapist_note text;
alter table public.session_reviews add column if not exists reviewed_at timestamptz not null default now();
update public.session_reviews set note = '' where note is null;
update public.session_reviews set therapist_note = coalesce(therapist_note, note, '') where therapist_note is null;
alter table public.session_reviews alter column note set default '';
alter table public.session_reviews alter column note set not null;
alter table public.session_reviews alter column therapist_note set default '';
alter table public.session_reviews alter column therapist_note set not null;
create unique index if not exists session_reviews_session_therapist_uidx
  on public.session_reviews (session_id, therapist_id);
alter table public.sessions enable row level security;
alter table public.session_reviews enable row level security;
grant select, insert on public.sessions to authenticated;
grant select, insert, update on public.session_reviews to authenticated;

drop policy if exists "therapists create own mobile sessions" on public.sessions;
drop policy if exists "therapists read own mobile reviews" on public.session_reviews;
drop policy if exists "therapists write own mobile reviews" on public.session_reviews;
create policy "therapists create own mobile sessions" on public.sessions
for insert to authenticated with check (
  therapist_id = (select auth.uid())
  and exists (select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.enabled and p.role = 'therapist')
  and exists (select 1 from public.patients p
    where p.id = sessions.patient_id and p.therapist_id = (select auth.uid()) and not p.archived)
  and exists (select 1 from public.exercises e
    where e.id = sessions.exercise_id and e.enabled)
  and exists (select 1 from public.plans p
    join public.plan_versions v on v.plan_id = p.id
    where p.id = sessions.plan_id and p.patient_id = sessions.patient_id
      and p.therapist_id = (select auth.uid()) and v.version = sessions.plan_version
      and sessions.exercise_id = any(v.exercise_ids))
  and analysis_status in ('ready', 'incomplete', 'failed')
  and duration_minutes >= 0 and repetitions >= 0
  and (range_degrees is null or range_degrees between 0 and 180)
  and analysis_payload->>'source' = 'android_camera'
);

create policy "therapists read own mobile reviews" on public.session_reviews
for select to authenticated using (therapist_id = (select auth.uid()));

create policy "therapists write own mobile reviews" on public.session_reviews
for all to authenticated using (therapist_id = (select auth.uid()))
with check (
  therapist_id = (select auth.uid())
  and length(trim(coalesce(therapist_note, note))) > 0
);

-- Fourth rule is available only when prescribed, as with the existing exercises.
insert into public.exercises (id, name, category, instructions, equipment, version, enabled)
values ('e4', 'Arm hold', 'Upper body',
  'Follow the therapist-agreed target. Hold the arm in the camera plane with a steady trunk. Stop if uncomfortable.',
  'Android phone on a stable stand', 1, true)
on conflict (id) do nothing;
commit;

-- Refresh PostgREST metadata so newly added review columns are visible immediately.
notify pgrst, 'reload schema';
