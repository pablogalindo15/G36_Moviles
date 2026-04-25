create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  amount numeric not null,
  currency text not null,
  category text not null,
  note text,
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  client_uuid uuid not null default gen_random_uuid()
);

alter table public.expenses enable row level security;

create index if not exists idx_expenses_user_occurred_at
  on public.expenses (user_id, occurred_at desc);

create index if not exists idx_expenses_currency_occurred_at
  on public.expenses (currency, occurred_at desc);

drop policy if exists "expenses_select_own" on public.expenses;
create policy "expenses_select_own"
on public.expenses
for select
using (auth.uid() = user_id);

drop policy if exists "expenses_insert_own" on public.expenses;
create policy "expenses_insert_own"
on public.expenses
for insert
with check (auth.uid() = user_id);

drop policy if exists "expenses_update_own" on public.expenses;
create policy "expenses_update_own"
on public.expenses
for update
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "expenses_delete_own" on public.expenses;
create policy "expenses_delete_own"
on public.expenses
for delete
using (auth.uid() = user_id);

create or replace function public.sanitize_and_validate_expense()
returns trigger
language plpgsql
as $$
begin
  new.currency := upper(trim(new.currency));
  new.category := trim(new.category);
  new.note := nullif(
    regexp_replace(
      regexp_replace(trim(coalesce(new.note, '')), '[[:cntrl:]]', '', 'g'),
      '[[:space:]]+',
      ' ',
      'g'
    ),
    ''
  );

  if new.amount <= 0 then
    raise exception 'Expense amount must be greater than zero';
  end if;

  if new.amount > 10000000 then
    raise exception 'Expense amount must not exceed 10000000';
  end if;

  if new.currency = '' then
    raise exception 'Currency is required';
  end if;

  if new.category = '' then
    raise exception 'Category is required';
  end if;

  if new.note is not null and char_length(new.note) > 100 then
    raise exception 'Expense note must not exceed 100 characters';
  end if;

  if new.note is not null
    and new.note ~* '(^|[^[:alnum:]_])(select|insert|update|delete|drop|truncate|alter|create|grant|revoke|union|exec|execute)([^[:alnum:]_]|$)|--|/\*|\*/|;'
  then
    raise exception 'Expense note contains forbidden SQL-like content';
  end if;

  return new;
end;
$$;

update public.expenses
set
  currency = upper(trim(currency)),
  category = trim(category),
  note = case
    when note is null then null
    else nullif(
      case
        when regexp_replace(
          regexp_replace(trim(note), '[[:cntrl:]]', '', 'g'),
          '[[:space:]]+',
          ' ',
          'g'
        ) ~* '(^|[^[:alnum:]_])(select|insert|update|delete|drop|truncate|alter|create|grant|revoke|union|exec|execute)([^[:alnum:]_]|$)|--|/\*|\*/|;'
          then ''
        else left(
          regexp_replace(
            regexp_replace(trim(note), '[[:cntrl:]]', '', 'g'),
            '[[:space:]]+',
            ' ',
            'g'
          ),
          100
        )
      end,
      ''
    )
  end;

drop trigger if exists trg_expenses_sanitize_validate on public.expenses;
create trigger trg_expenses_sanitize_validate
before insert or update on public.expenses
for each row execute function public.sanitize_and_validate_expense();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'expenses_amount_positive_chk'
  ) then
    alter table public.expenses
      add constraint expenses_amount_positive_chk
      check (amount > 0);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'expenses_amount_max_chk'
  ) then
    alter table public.expenses
      add constraint expenses_amount_max_chk
      check (amount <= 10000000);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'expenses_note_length_chk'
  ) then
    alter table public.expenses
      add constraint expenses_note_length_chk
      check (note is null or char_length(note) <= 100);
  end if;
end
$$;
