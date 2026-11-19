-- MazWaveTours: visitantes activos y formularios completados
-- Ejecutar una sola vez en Supabase > SQL Editor.
create table if not exists public.site_live_visitors (
  visitor_id uuid primary key,
  page_path text not null default '/',
  last_seen_at timestamptz not null default now()
);
create index if not exists site_live_visitors_last_seen_idx on public.site_live_visitors(last_seen_at desc);
create table if not exists public.site_form_submissions (
  id bigint generated always as identity primary key,
  visitor_id uuid not null,
  page_path text not null default '/',
  item_name text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists site_form_submissions_created_idx on public.site_form_submissions(created_at desc);
create index if not exists site_form_submissions_visitor_idx on public.site_form_submissions(visitor_id, created_at desc);
alter table public.site_live_visitors enable row level security;
alter table public.site_form_submissions enable row level security;
revoke all on public.site_live_visitors from anon, authenticated;
revoke all on public.site_form_submissions from anon, authenticated;

create or replace function public.track_site_visitor(p_visitor_id uuid, p_page_path text default '/')
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_visitor_id is null then return; end if;
  insert into public.site_live_visitors(visitor_id,page_path,last_seen_at)
  values (p_visitor_id,left(coalesce(nullif(p_page_path,''),'/'),300),now())
  on conflict(visitor_id) do update set page_path=excluded.page_path,last_seen_at=excluded.last_seen_at;
  delete from public.site_live_visitors where last_seen_at < now() - interval '1 day';
end; $$;
revoke all on function public.track_site_visitor(uuid,text) from public;
grant execute on function public.track_site_visitor(uuid,text) to anon, authenticated;

create or replace function public.register_site_form_submission(p_visitor_id uuid,p_page_path text default '/',p_item_name text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_visitor_id is null then return; end if;
  if exists(select 1 from public.site_form_submissions where visitor_id=p_visitor_id and created_at>now()-interval '15 seconds') then return; end if;
  insert into public.site_form_submissions(visitor_id,page_path,item_name)
  values(p_visitor_id,left(coalesce(nullif(p_page_path,''),'/'),300),left(coalesce(p_item_name,''),160));
end; $$;
revoke all on function public.register_site_form_submission(uuid,text,text) from public;
grant execute on function public.register_site_form_submission(uuid,text,text) to anon, authenticated;

create or replace function public.get_admin_site_metrics()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_active integer; v_total integer; v_today integer; v_pages jsonb;
begin
  if auth.uid() is null or not coalesce(public.is_mazwave_admin(),false) then
    raise exception 'No autorizado' using errcode='42501';
  end if;
  delete from public.site_live_visitors where last_seen_at < now()-interval '1 day';
  select count(*) into v_active from public.site_live_visitors where last_seen_at>=now()-interval '5 minutes';
  select count(*) into v_total from public.site_form_submissions;
  select count(*) into v_today from public.site_form_submissions
    where created_at >= (date_trunc('day',now() at time zone 'America/Mazatlan') at time zone 'America/Mazatlan');
  select coalesce(jsonb_agg(jsonb_build_object('path',page_path,'visitors',visitors) order by visitors desc),'[]'::jsonb)
    into v_pages from (select page_path,count(*)::integer visitors from public.site_live_visitors
      where last_seen_at>=now()-interval '5 minutes' group by page_path order by count(*) desc limit 8) pages;
  return jsonb_build_object('active_visitors',v_active,'forms_total',v_total,'forms_today',v_today,'active_pages',v_pages);
end; $$;
revoke all on function public.get_admin_site_metrics() from public,anon;
grant execute on function public.get_admin_site_metrics() to authenticated;
