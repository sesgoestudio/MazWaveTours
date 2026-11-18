-- MazWaveTours: bucket independiente para videos de las actividades del inicio.
-- Ejecutar una sola vez en Supabase → SQL Editor.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'mazwave-videos',
  'mazwave-videos',
  true,
  52428800,
  array['video/mp4','video/webm','video/quicktime']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view MazWave activity videos" on storage.objects;
create policy "Public can view MazWave activity videos" on storage.objects
for select to public using (bucket_id = 'mazwave-videos');

drop policy if exists "MazWave admin can upload activity videos" on storage.objects;
create policy "MazWave admin can upload activity videos" on storage.objects
for insert to authenticated
with check (bucket_id = 'mazwave-videos' and public.is_mazwave_admin());

drop policy if exists "MazWave admin can update activity videos" on storage.objects;
create policy "MazWave admin can update activity videos" on storage.objects
for update to authenticated
using (bucket_id = 'mazwave-videos' and public.is_mazwave_admin())
with check (bucket_id = 'mazwave-videos' and public.is_mazwave_admin());

drop policy if exists "MazWave admin can delete activity videos" on storage.objects;
create policy "MazWave admin can delete activity videos" on storage.objects
for delete to authenticated
using (bucket_id = 'mazwave-videos' and public.is_mazwave_admin());
