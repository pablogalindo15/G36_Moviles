-- Fluxo backend scaffold (MVP)
-- Minimal schema + RLS + storage policies for:
-- 1) Sign in / Create account
-- 2) Profile data + avatar upload
-- 3) Setup first plan + generated plan persistence

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.financial_setups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  currency text not null,
  monthly_income numeric not null,
  fixed_monthly_expenses numeric not null,
  monthly_savings_goal numeric not null,
  next_payday date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.generated_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  financial_setup_id uuid not null references public.financial_setups (id) on delete cascade,
  safe_to_spend_until_next_payday numeric not null,
  weekly_cap numeric not null,
  target_savings numeric not null,
  contextual_insight_message text not null,
  generated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists trg_financial_setups_updated_at on public.financial_setups;
create trigger trg_financial_setups_updated_at
before update on public.financial_setups
for each row execute function public.set_updated_at();

-- Automatically create a profile when a new auth user signs up.
create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id)
  values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_auth_user_created on auth.users;
create trigger trg_auth_user_created
after insert on auth.users
for each row execute function public.create_profile_for_new_user();

-- RLS
alter table public.profiles enable row level security;
alter table public.financial_setups enable row level security;
alter table public.generated_plans enable row level security;

-- Profiles policies
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
using (auth.uid() = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
with check (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "profiles_delete_own" on public.profiles;
create policy "profiles_delete_own"
on public.profiles
for delete
using (auth.uid() = id);

-- Financial setups policies
drop policy if exists "financial_setups_select_own" on public.financial_setups;
create policy "financial_setups_select_own"
on public.financial_setups
for select
using (auth.uid() = user_id);

drop policy if exists "financial_setups_insert_own" on public.financial_setups;
create policy "financial_setups_insert_own"
on public.financial_setups
for insert
with check (auth.uid() = user_id);

drop policy if exists "financial_setups_update_own" on public.financial_setups;
create policy "financial_setups_update_own"
on public.financial_setups
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "financial_setups_delete_own" on public.financial_setups;
create policy "financial_setups_delete_own"
on public.financial_setups
for delete
using (auth.uid() = user_id);

-- Generated plans policies
drop policy if exists "generated_plans_select_own" on public.generated_plans;
create policy "generated_plans_select_own"
on public.generated_plans
for select
using (auth.uid() = user_id);

drop policy if exists "generated_plans_insert_own" on public.generated_plans;
create policy "generated_plans_insert_own"
on public.generated_plans
for insert
with check (auth.uid() = user_id);

drop policy if exists "generated_plans_update_own" on public.generated_plans;
create policy "generated_plans_update_own"
on public.generated_plans
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "generated_plans_delete_own" on public.generated_plans;
create policy "generated_plans_delete_own"
on public.generated_plans
for delete
using (auth.uid() = user_id);

-- Storage bucket + policies for avatars.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'avatars',
  'avatars',
  false,
  52428800,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do nothing;

drop policy if exists "avatars_select_own" on storage.objects;
create policy "avatars_select_own"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own"
on storage.objects
for update
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);

drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own"
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = auth.uid()::text
);
