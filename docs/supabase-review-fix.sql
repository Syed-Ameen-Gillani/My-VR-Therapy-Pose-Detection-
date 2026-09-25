-- Run once in the Supabase SQL Editor if review saving reports PGRST204 for note.
begin;

alter table public.session_reviews
  add column if not exists session_id text,
  add column if not exists therapist_id uuid,
  add column if not exists note text,
  add column if not exists therapist_note text,
  add column if not exists reviewed_at timestamptz not null default now();

update public.session_reviews
set note = coalesce(note, therapist_note, '')
where note is null;

update public.session_reviews
set therapist_note = coalesce(therapist_note, note, '')
where therapist_note is null;

alter table public.session_reviews
  alter column note set default '',
  alter column note set not null,
  alter column therapist_note set default '',
  alter column therapist_note set not null;

create unique index if not exists session_reviews_session_therapist_uidx
  on public.session_reviews (session_id, therapist_id);

alter table public.session_reviews enable row level security;
grant select, insert, update on public.session_reviews to authenticated;

drop policy if exists "therapists read own mobile reviews" on public.session_reviews;
drop policy if exists "therapists write own mobile reviews" on public.session_reviews;

create policy "therapists read own mobile reviews" on public.session_reviews
for select to authenticated
using (therapist_id = (select auth.uid()));

create policy "therapists write own mobile reviews" on public.session_reviews
for all to authenticated
using (therapist_id = (select auth.uid()))
with check (
  therapist_id = (select auth.uid())
  and length(trim(coalesce(therapist_note, note))) > 0
);

commit;
notify pgrst, 'reload schema';
