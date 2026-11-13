-- MazWaveTours: catálogo compartido y acceso exclusivo de administradores
create table if not exists public.site_config (
  id integer primary key check (id = 1),
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- Autoriza únicamente al usuario administrador creado en Supabase Auth.
insert into public.app_admins (user_id)
values ('ed265c7f-623f-4337-8935-e5a864e5db5f'::uuid)
on conflict (user_id) do nothing;

alter table public.site_config enable row level security;
alter table public.app_admins enable row level security;

-- El público puede leer el catálogo, pero no modificarlo.
drop policy if exists "Public can read catalog" on public.site_config;
create policy "Public can read catalog"
on public.site_config for select
to anon, authenticated
using (true);

create or replace function public.is_mazwave_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.app_admins
    where user_id = auth.uid()
  );
$$;

revoke all on function public.is_mazwave_admin() from public;
grant execute on function public.is_mazwave_admin() to authenticated;

drop policy if exists "Authenticated admins can insert catalog" on public.site_config;
create policy "Authenticated admins can insert catalog"
on public.site_config for insert
to authenticated
with check (public.is_mazwave_admin());

drop policy if exists "Authenticated admins can update catalog" on public.site_config;
create policy "Authenticated admins can update catalog"
on public.site_config for update
to authenticated
using (public.is_mazwave_admin())
with check (public.is_mazwave_admin());

-- La tabla de administradores no se expone a clientes.
revoke all on table public.app_admins from anon, authenticated;

-- El administrador puede crear la fila inicial al guardar desde /admin/.
