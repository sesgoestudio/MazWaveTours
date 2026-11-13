-- MazWaveTours: catálogo central, administrador único y almacenamiento de fotografías
create table if not exists public.site_config (
  id integer primary key check (id = 1),
  data jsonb not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

insert into public.app_admins (user_id)
values ('ed265c7f-623f-4337-8935-e5a864e5db5f'::uuid)
on conflict (user_id) do nothing;

alter table public.site_config enable row level security;
alter table public.app_admins enable row level security;

create or replace function public.is_mazwave_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.app_admins where user_id = auth.uid());
$$;

revoke all on function public.is_mazwave_admin() from public;
grant execute on function public.is_mazwave_admin() to authenticated;

drop policy if exists "Public can read catalog" on public.site_config;
create policy "Public can read catalog" on public.site_config
for select to anon, authenticated using (true);

drop policy if exists "Authenticated admins can insert catalog" on public.site_config;
create policy "Authenticated admins can insert catalog" on public.site_config
for insert to authenticated with check (public.is_mazwave_admin());

drop policy if exists "Authenticated admins can update catalog" on public.site_config;
create policy "Authenticated admins can update catalog" on public.site_config
for update to authenticated using (public.is_mazwave_admin())
with check (public.is_mazwave_admin());

revoke all on table public.app_admins from anon, authenticated;

-- Bucket público: cualquiera puede ver imágenes; solo el administrador puede subir, reemplazar o borrar.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('mazwave-images', 'mazwave-images', true, 8388608,
        array['image/jpeg','image/png','image/webp','image/gif','image/avif'])
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view MazWave images" on storage.objects;
create policy "Public can view MazWave images" on storage.objects
for select to public using (bucket_id = 'mazwave-images');

drop policy if exists "MazWave admin can upload images" on storage.objects;
create policy "MazWave admin can upload images" on storage.objects
for insert to authenticated
with check (bucket_id = 'mazwave-images' and public.is_mazwave_admin());

drop policy if exists "MazWave admin can update images" on storage.objects;
create policy "MazWave admin can update images" on storage.objects
for update to authenticated
using (bucket_id = 'mazwave-images' and public.is_mazwave_admin())
with check (bucket_id = 'mazwave-images' and public.is_mazwave_admin());

drop policy if exists "MazWave admin can delete images" on storage.objects;
create policy "MazWave admin can delete images" on storage.objects
for delete to authenticated
using (bucket_id = 'mazwave-images' and public.is_mazwave_admin());

-- La primera vez que el administrador entre al panel, se carga el catálogo completo de respaldo
-- (24 experiencias y sus campos) en site_config si aún no existe una fila.
