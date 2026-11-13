-- MazWaveTours: booking and availability foundation
-- Apply with the Supabase SQL editor or Supabase CLI after creating a project.
-- No credentials or project-specific identifiers belong in this file.

create extension if not exists pgcrypto;
create extension if not exists btree_gist;

create type public.staff_role as enum ('customer', 'staff', 'admin');
create type public.booking_request_status as enum ('pending', 'contacted', 'quoted', 'converted', 'closed');

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role public.staff_role not null default 'customer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.vessels (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  capacity integer not null check (capacity > 0),
  description text not null default '',
  price_amount numeric(12,2) check (price_amount is null or price_amount >= 0),
  currency text not null default 'MXN' check (currency = 'MXN'),
  image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.booking_requests (
  id uuid primary key default gen_random_uuid(),
  vessel_id uuid references public.vessels(id) on delete set null,
  customer_name text not null check (char_length(trim(customer_name)) between 2 and 120),
  customer_phone text not null check (char_length(trim(customer_phone)) between 7 and 30),
  customer_email text check (customer_email is null or char_length(customer_email) <= 254),
  requested_start timestamptz not null,
  requested_end timestamptz not null,
  guests integer not null check (guests > 0),
  notes text not null default '' check (char_length(notes) <= 2000),
  status public.booking_request_status not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint booking_request_valid_period check (requested_end > requested_start),
  constraint booking_request_future check (requested_start > now())
);

create table public.availability_blocks (
  id uuid primary key default gen_random_uuid(),
  vessel_id uuid not null references public.vessels(id) on delete cascade,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  reason text not null default 'blocked',
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint availability_block_valid_period check (ends_at > starts_at)
);

create table public.reservations (
  id uuid primary key default gen_random_uuid(),
  vessel_id uuid not null references public.vessels(id),
  booking_request_id uuid unique references public.booking_requests(id) on delete set null,
  customer_name text not null,
  customer_phone text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  guests integer not null check (guests > 0),
  status text not null default 'confirmed' check (status in ('confirmed', 'cancelled')),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint reservation_valid_period check (ends_at > starts_at),
  constraint reservation_no_overlap exclude using gist (
    vessel_id with =,
    tstzrange(starts_at, ends_at, '[)') with &&
  ) where (status = 'confirmed')
);

create index booking_requests_start_idx on public.booking_requests(requested_start);
create index availability_blocks_vessel_period_idx on public.availability_blocks using gist (vessel_id, tstzrange(starts_at, ends_at, '[)'));
create index reservations_vessel_period_idx on public.reservations using gist (vessel_id, tstzrange(starts_at, ends_at, '[)'));

create trigger profiles_updated_at before update on public.profiles
for each row execute function public.set_updated_at();
create trigger vessels_updated_at before update on public.vessels
for each row execute function public.set_updated_at();
create trigger booking_requests_updated_at before update on public.booking_requests
for each row execute function public.set_updated_at();
create trigger reservations_updated_at before update on public.reservations
for each row execute function public.set_updated_at();

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role in ('staff', 'admin')
  );
$$;

alter table public.profiles enable row level security;
alter table public.vessels enable row level security;
alter table public.booking_requests enable row level security;
alter table public.availability_blocks enable row level security;
alter table public.reservations enable row level security;

create policy "Users can read own profile"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or (select public.is_staff()));

-- No self-service profile update policy: role assignment must be performed by a trusted admin.
create policy "Public can view active vessels"
on public.vessels for select to anon, authenticated
using (is_active or (select public.is_staff()));
create policy "Staff manage vessels"
on public.vessels for all to authenticated
using ((select public.is_staff()))
with check ((select public.is_staff()));

create policy "Public can submit booking requests"
on public.booking_requests for insert to anon, authenticated
with check (
  status = 'pending'
  and requested_start > now()
  and exists (
    select 1 from public.vessels v
    where v.id = vessel_id and v.is_active and guests <= v.capacity
  )
);
create policy "Staff read booking requests"
on public.booking_requests for select to authenticated
using ((select public.is_staff()));
create policy "Staff update booking requests"
on public.booking_requests for update to authenticated
using ((select public.is_staff()))
with check ((select public.is_staff()));

create policy "Staff manage availability blocks"
on public.availability_blocks for all to authenticated
using ((select public.is_staff()))
with check ((select public.is_staff()));

create policy "Staff manage reservations"
on public.reservations for all to authenticated
using ((select public.is_staff()))
with check ((select public.is_staff()));

-- Important: never expose the service_role key in the browser.
-- Configure an Auth user as admin only from a trusted SQL session after verifying its UUID:
-- update public.profiles set role = 'admin' where id = '<verified-auth-user-uuid>';
