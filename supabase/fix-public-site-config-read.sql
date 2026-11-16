-- MazWaveTours: permitir que el sitio público lea la configuración del inicio.
-- No concede permisos de escritura a visitantes.
grant usage on schema public to anon, authenticated;
grant select on table public.site_config to anon, authenticated;

drop policy if exists "Public can read catalog" on public.site_config;
create policy "Public can read catalog" on public.site_config
for select to anon, authenticated
using (true);

-- Las escrituras siguen restringidas a la cuenta administradora mediante is_mazwave_admin().
