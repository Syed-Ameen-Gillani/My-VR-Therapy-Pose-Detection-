create extension if not exists pgcrypto;

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role text not null default 'therapist',
  enabled boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists patients (
  id text primary key,
  therapist_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  initials text not null,
  goal text not null,
  archived boolean not null default false,
  active_plan_id text,
  revision integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists exercises (
  id text primary key,
  name text not null,
  category text not null,
  instructions text not null,
  equipment text not null,
  version integer not null default 1,
  enabled boolean not null default true
);

alter table exercises add column if not exists version integer not null default 1;
alter table exercises add column if not exists enabled boolean not null default true;

create table if not exists plans (
  id text primary key,
  patient_id text not null references patients(id) on delete cascade,
  therapist_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  exercise_ids text[] not null default '{}',
  scheduled_sessions integer not null check (scheduled_sessions between 1 and 12),
  version integer not null default 1,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table plans add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'patients_active_plan_fk'
  ) then
    alter table patients
      add constraint patients_active_plan_fk
      foreign key (active_plan_id) references plans(id);
  end if;
end;
$$;

create table if not exists plan_versions (
  id bigint generated always as identity primary key,
  plan_id text not null references plans(id) on delete cascade,
  version integer not null,
  title text not null,
  exercise_ids text[] not null default '{}',
  scheduled_sessions integer not null,
  created_at timestamptz not null default now(),
  unique (plan_id, version)
);

create table if not exists sessions (
  id text primary key,
  patient_id text not null references patients(id) on delete cascade,
  therapist_id uuid not null references auth.users(id) on delete cascade,
  exercise_id text not null references exercises(id),
  plan_id text references plans(id),
  plan_version integer,
  started_at timestamptz not null,
  duration_minutes integer not null default 0,
  repetitions integer not null default 0,
  analysis_status text not null default 'pending',
  range_degrees numeric,
  reviewed boolean not null default false,
  analysis_payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists session_reviews (
  id bigint generated always as identity primary key,
  session_id text not null references sessions(id) on delete cascade,
  therapist_id uuid not null references auth.users(id) on delete cascade,
  note text not null,
  reviewed_at timestamptz not null default now(),
  unique (session_id, therapist_id)
);

create index if not exists patients_therapist_active_idx
  on patients (therapist_id, archived, name);

create index if not exists plans_therapist_patient_status_idx
  on plans (therapist_id, patient_id, status);

create index if not exists sessions_therapist_started_idx
  on sessions (therapist_id, started_at desc);

create index if not exists sessions_patient_started_idx
  on sessions (patient_id, started_at desc);

create or replace function activate_plan(
  p_patient_id text,
  p_title text,
  p_exercise_ids text[],
  p_scheduled_sessions integer
)
returns table (
  id text,
  patient_id text,
  title text,
  exercise_ids text[],
  scheduled_sessions integer,
  version integer,
  status text
)
language plpgsql
security invoker
as $$
declare
  v_therapist_id uuid := auth.uid();
  v_plan_id text;
  v_version integer;
begin
  if v_therapist_id is null then
    raise exception 'Authentication required';
  end if;

  if p_scheduled_sessions < 1 or p_scheduled_sessions > 12 then
    raise exception 'scheduled_sessions must be between 1 and 12';
  end if;

  if coalesce(array_length(p_exercise_ids, 1), 0) = 0 then
    raise exception 'At least one exercise is required';
  end if;

  if not exists (
    select 1
    from patients
    where patients.id = p_patient_id
      and patients.therapist_id = v_therapist_id
      and patients.archived = false
  ) then
    raise exception 'Patient not found';
  end if;

  select plans.id, plans.version + 1
  into v_plan_id, v_version
  from plans
  where plans.patient_id = p_patient_id
    and plans.therapist_id = v_therapist_id
    and plans.status = 'active'
  limit 1
  for update;

  if v_plan_id is null then
    v_plan_id := 'plan_' || replace(gen_random_uuid()::text, '-', '');
    v_version := 1;

    insert into plans (
      id,
      patient_id,
      therapist_id,
      title,
      exercise_ids,
      scheduled_sessions,
      version,
      status
    ) values (
      v_plan_id,
      p_patient_id,
      v_therapist_id,
      trim(p_title),
      p_exercise_ids,
      p_scheduled_sessions,
      v_version,
      'active'
    );
  else
    update plans
    set title = trim(p_title),
        exercise_ids = p_exercise_ids,
        scheduled_sessions = p_scheduled_sessions,
        version = v_version,
        updated_at = now()
    where plans.id = v_plan_id
      and plans.therapist_id = v_therapist_id;
  end if;

  insert into plan_versions (
    plan_id,
    version,
    title,
    exercise_ids,
    scheduled_sessions
  ) values (
    v_plan_id,
    v_version,
    trim(p_title),
    p_exercise_ids,
    p_scheduled_sessions
  );

  update patients
  set active_plan_id = v_plan_id,
      updated_at = now()
  where patients.id = p_patient_id
    and patients.therapist_id = v_therapist_id;

  return query
  select
    plans.id,
    plans.patient_id,
    plans.title,
    plans.exercise_ids,
    plans.scheduled_sessions,
    plans.version,
    plans.status
  from plans
  where plans.id = v_plan_id
    and plans.therapist_id = v_therapist_id;
end;
$$;

grant execute on function activate_plan(text, text, text[], integer) to authenticated;

alter table profiles enable row level security;
alter table patients enable row level security;
alter table exercises enable row level security;
alter table plans enable row level security;
alter table plan_versions enable row level security;
alter table sessions enable row level security;
alter table session_reviews enable row level security;

drop policy if exists "read own profile" on profiles;
drop policy if exists "therapists read own patients" on patients;
drop policy if exists "therapists create own patients" on patients;
drop policy if exists "therapists update own patients" on patients;
drop policy if exists "read enabled exercises" on exercises;
drop policy if exists "therapists read own plans" on plans;
drop policy if exists "therapists create own plans" on plans;
drop policy if exists "therapists update own plans" on plans;
drop policy if exists "therapists read own plan versions" on plan_versions;
drop policy if exists "therapists create own plan versions" on plan_versions;
drop policy if exists "therapists read own sessions" on sessions;
drop policy if exists "therapists read own reviews" on session_reviews;
drop policy if exists "therapists write own reviews" on session_reviews;
drop policy if exists "therapists update own reviews" on session_reviews;

create policy "read own profile" on profiles
  for select using (id = auth.uid());

create policy "therapists read own patients" on patients
  for select using (therapist_id = auth.uid() and archived = false);

create policy "therapists create own patients" on patients
  for insert with check (therapist_id = auth.uid());

create policy "therapists update own patients" on patients
  for update using (therapist_id = auth.uid())
  with check (therapist_id = auth.uid());

create policy "read enabled exercises" on exercises
  for select using (enabled = true);

create policy "therapists read own plans" on plans
  for select using (therapist_id = auth.uid());

create policy "therapists create own plans" on plans
  for insert with check (therapist_id = auth.uid());

create policy "therapists update own plans" on plans
  for update using (therapist_id = auth.uid())
  with check (therapist_id = auth.uid());

create policy "therapists read own plan versions" on plan_versions
  for select using (
    exists (
      select 1 from plans
      where plans.id = plan_versions.plan_id
        and plans.therapist_id = auth.uid()
    )
  );

create policy "therapists create own plan versions" on plan_versions
  for insert with check (
    exists (
      select 1 from plans
      where plans.id = plan_versions.plan_id
        and plans.therapist_id = auth.uid()
    )
  );

create policy "therapists read own sessions" on sessions
  for select using (therapist_id = auth.uid());

create policy "therapists read own reviews" on session_reviews
  for select using (therapist_id = auth.uid());

create policy "therapists write own reviews" on session_reviews
  for insert with check (therapist_id = auth.uid());

create policy "therapists update own reviews" on session_reviews
  for update using (therapist_id = auth.uid())
  with check (therapist_id = auth.uid());

insert into exercises (id, name, category, instructions, equipment)
values
  (
    'e1',
    'Shoulder reach',
    'Upper body',
    'Reach forward slowly while keeping movement controlled.',
    'VR headset and controllers'
  ),
  (
    'e2',
    'Seated knee extension',
    'Lower body',
    'Extend the knee while seated and return slowly.',
    'Chair and agreed tracking system'
  ),
  (
    'e3',
    'Seated balance',
    'Balance',
    'Maintain seated balance while following VR prompts.',
    'Chair and VR headset'
  ),
  (
    'e4',
    'Arm hold',
    'Upper body',
    'Hold the arm in the camera plane at the therapist-agreed target.',
    'Android phone on a stable stand'
  ),
  (
    'e5',
    'Elbow flexion',
    'Upper body',
    'Bend and slowly straighten the selected elbow in view.',
    'Android phone on a stable stand'
  ),
  (
    'e6',
    'Seated hip flexion',
    'Lower body',
    'Lift the selected knee gently while seated, then lower it.',
    'Chair and Android phone'
  ),
  (
    'e7',
    'Seated knee flexion',
    'Lower body',
    'Bend and extend the selected knee within the agreed range.',
    'Chair and Android phone'
  ),
  (
    'e8',
    'Shoulder abduction',
    'Upper body',
    'Raise the selected arm out to the side and return slowly.',
    'Android phone on a stable stand'
  ),
  (
    'e9',
    'Trunk alignment hold',
    'Posture',
    'Sit tall and hold your trunk centered with steady shoulders.',
    'Chair and Android phone'
  ),
  (
    'e10',
    'Sit to stand',
    'Functional movement',
    'Stand from the chair with control, then sit down slowly.',
    'Stable chair and Android phone'
  )
on conflict (id) do update
set name = excluded.name,
    category = excluded.category,
    instructions = excluded.instructions,
    equipment = excluded.equipment,
    enabled = true;
