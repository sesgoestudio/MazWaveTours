-- MazWaveTours: catálogo compartido entre admin y sitio público
create table if not exists public.site_config (
  id integer primary key check (id = 1),
  data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.site_config enable row level security;

drop policy if exists "Public can read catalog" on public.site_config;
create policy "Public can read catalog"
on public.site_config for select
to anon, authenticated
using (true);

drop policy if exists "Authenticated admins can insert catalog" on public.site_config;
create policy "Authenticated admins can insert catalog"
on public.site_config for insert
to authenticated
with check (true);

drop policy if exists "Authenticated admins can update catalog" on public.site_config;
create policy "Authenticated admins can update catalog"
on public.site_config for update
to authenticated
using (true)
with check (true);

-- Insertar datos iniciales: ejecuta una sola vez después de copiar el catálogo inicial
-- El administrador también puede crear la fila al guardar por primera vez.
