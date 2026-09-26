-- Fix for missing updated_at column on public.plans table
-- Run this once in the Supabase SQL Editor if you want the database RPC activate_plan to update updated_at directly.

begin;

alter table public.plans add column if not exists updated_at timestamptz not null default now();

commit;

notify pgrst, 'reload schema';
