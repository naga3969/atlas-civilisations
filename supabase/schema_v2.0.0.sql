-- =====================================================================
--  Atlas des civilisations — schéma Supabase  v2.0.0
--  À exécuter en une fois dans Supabase > SQL Editor (projet vierge).
--
--  Rôles applicatifs (table profiles.role) :
--    contributor  compte créé librement : propose, ne publie pas
--    editor       publie directement et valide les propositions
--    admin        idem + gestion des rôles et réinitialisation
--  Les visiteurs non connectés lisent les données (rôle Postgres "anon").
--
--  Toute écriture passe par des fonctions SECURITY DEFINER qui vérifient
--  le rôle : la clé "anon" publiée dans config.js ne permet rien d'autre
--  que lire les données et déposer une proposition à son propre nom.
-- =====================================================================

-- ---------------------------------------------------------------- profils
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role         text not null default 'contributor'
               check (role in ('contributor', 'editor', 'admin')),
  created_at   timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, left(coalesce(nullif(trim(new.raw_user_meta_data->>'display_name'), ''),
                                split_part(new.email, '@', 1)), 60))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users for each row execute function public.handle_new_user();

create or replace function public.my_role()
returns text language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_editor()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() in ('editor', 'admin'), false)
$$;

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() = 'admin', false)
$$;

alter table public.profiles enable row level security;
drop policy if exists profiles_read_own on public.profiles;
create policy profiles_read_own on public.profiles
  for select to authenticated using (id = auth.uid() or public.is_admin());

-- seul le nom affiché est modifiable par l'intéressé ; le rôle passe par set_role()
revoke update on public.profiles from authenticated, anon;
grant update (display_name) on public.profiles to authenticated;
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- ---------------------------------------------------------------- données
--  Un enregistrement par élément de l'atlas ; "data" contient l'objet tel que
--  l'application le manipule (civilisation, territoire, événement…).
create table if not exists public.items (
  coll       text not null check (coll in ('civs', 'territories', 'events', 'pois', 'links', 'subjections')),
  id         text not null check (length(id) between 1 and 80),
  data       jsonb not null check (jsonb_typeof(data) = 'object' and pg_column_size(data) < 1000000),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null,
  primary key (coll, id)
);

alter table public.items enable row level security;
drop policy if exists items_public_read on public.items;
create policy items_public_read on public.items for select to anon, authenticated using (true);
-- aucune politique d'écriture : seules les fonctions ci-dessous écrivent.
revoke insert, update, delete, truncate on public.items from anon, authenticated;

-- historique : chaque version remplacée ou supprimée est conservée
create table if not exists public.item_history (
  hid        bigint generated always as identity primary key,
  coll       text not null,
  id         text not null,
  op         text not null,
  old_data   jsonb,
  changed_by uuid,
  changed_at timestamptz not null default now()
);
alter table public.item_history enable row level security;
drop policy if exists history_editor_read on public.item_history;
create policy history_editor_read on public.item_history for select to authenticated using (public.is_editor());

create or replace function public.items_audit()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.item_history (coll, id, op, old_data, changed_by)
  values (old.coll, old.id, lower(tg_op), old.data, auth.uid());
  return null;
end $$;
drop trigger if exists items_audit on public.items;
create trigger items_audit after update or delete on public.items
  for each row execute function public.items_audit();

-- application d'une liste de changements [{coll, id, op:'upsert'|'delete', data}]
create or replace function public._apply_changes(p_changes jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare c jsonb; n integer := 0;
begin
  if jsonb_typeof(p_changes) <> 'array' then raise exception 'changes doit être un tableau'; end if;
  for c in select * from jsonb_array_elements(p_changes) loop
    if c->>'op' = 'delete' then
      delete from public.items where coll = c->>'coll' and id = c->>'id';
    elsif c->>'op' = 'upsert' then
      if (c->'data'->>'id') is distinct from (c->>'id') then
        raise exception 'identifiant incohérent : %', c->>'id';
      end if;
      insert into public.items (coll, id, data, updated_by, updated_at)
      values (c->>'coll', c->>'id', c->'data', auth.uid(), now())
      on conflict (coll, id) do update
        set data = excluded.data, updated_by = excluded.updated_by, updated_at = now()
        where public.items.data is distinct from excluded.data;
    else
      raise exception 'opération inconnue : %', c->>'op';
    end if;
    n := n + 1;
  end loop;
  return n;
end $$;
revoke all on function public._apply_changes(jsonb) from public, anon, authenticated;

-- publication directe (éditeurs)
create or replace function public.apply_changes(p_changes jsonb)
returns integer language plpgsql security definer set search_path = public as $$
begin
  if not public.is_editor() then raise exception 'Droits insuffisants' using errcode = '42501'; end if;
  return public._apply_changes(p_changes);
end $$;

-- remplacement complet (administrateurs) : initialisation depuis data/atlas.json
create or replace function public.replace_all(p_db jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare k text; o jsonb; n integer := 0;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs' using errcode = '42501'; end if;
  delete from public.items where true;
  foreach k in array array['civs', 'territories', 'events', 'pois', 'links', 'subjections'] loop
    for o in select * from jsonb_array_elements(coalesce(p_db->k, '[]'::jsonb)) loop
      insert into public.items (coll, id, data, updated_by) values (k, o->>'id', o, auth.uid());
      n := n + 1;
    end loop;
  end loop;
  return n;
end $$;

-- ------------------------------------------------------------ propositions
create table if not exists public.proposals (
  id             bigint generated always as identity primary key,
  author_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  author_name    text not null default '',
  created_at     timestamptz not null default now(),
  note           text not null default '' check (length(note) <= 4000),
  summary        text not null default '' check (length(summary) <= 4000),
  changes        jsonb not null check (jsonb_typeof(changes) = 'array'
                                       and jsonb_array_length(changes) between 1 and 2000
                                       and pg_column_size(changes) < 4000000),
  status         text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  reviewed_by    uuid references auth.users(id) on delete set null,
  reviewer_name  text,
  reviewed_at    timestamptz,
  review_comment text
);
create index if not exists proposals_status_idx on public.proposals (status, created_at desc);

-- à la création, le serveur impose l'auteur, la date et le statut
create or replace function public.proposals_before_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.author_id := auth.uid();
  new.author_name := coalesce((select display_name from public.profiles where id = auth.uid()), '?');
  new.created_at := now();
  new.status := 'pending';
  new.reviewed_by := null; new.reviewer_name := null; new.reviewed_at := null; new.review_comment := null;
  if (select count(*) from public.proposals where author_id = auth.uid() and status = 'pending') >= 20 then
    raise exception 'Trop de propositions en attente (20 au maximum)';
  end if;
  return new;
end $$;
drop trigger if exists proposals_before_insert on public.proposals;
create trigger proposals_before_insert before insert on public.proposals
  for each row execute function public.proposals_before_insert();

alter table public.proposals enable row level security;
drop policy if exists proposals_read on public.proposals;
create policy proposals_read on public.proposals for select to authenticated
  using (author_id = auth.uid() or public.is_editor());
drop policy if exists proposals_insert on public.proposals;
create policy proposals_insert on public.proposals for insert to authenticated
  with check (author_id = auth.uid());
drop policy if exists proposals_withdraw on public.proposals;
create policy proposals_withdraw on public.proposals for delete to authenticated
  using (author_id = auth.uid() and status = 'pending');
-- pas de politique UPDATE : la décision passe par review_proposal()
revoke update, truncate on public.proposals from anon, authenticated;
revoke insert, update, delete, truncate on public.item_history from anon, authenticated;

create or replace function public.review_proposal(p_id bigint, p_approve boolean, p_comment text default null)
returns void language plpgsql security definer set search_path = public as $$
declare p public.proposals;
begin
  if not public.is_editor() then raise exception 'Droits insuffisants' using errcode = '42501'; end if;
  select * into p from public.proposals where id = p_id for update;
  if not found then raise exception 'Proposition introuvable'; end if;
  if p.status <> 'pending' then raise exception 'Proposition déjà traitée'; end if;
  if p_approve then perform public._apply_changes(p.changes); end if;
  update public.proposals set
    status = case when p_approve then 'approved' else 'rejected' end,
    reviewed_by = auth.uid(),
    reviewer_name = (select display_name from public.profiles where id = auth.uid()),
    reviewed_at = now(),
    review_comment = left(p_comment, 2000)
  where id = p_id;
end $$;

-- ------------------------------------------------------------ utilisateurs
create or replace function public.list_users()
returns table (id uuid, email text, display_name text, role text, created_at timestamptz, last_sign_in_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs' using errcode = '42501'; end if;
  return query
    select p.id, u.email::text, p.display_name, p.role, p.created_at, u.last_sign_in_at
    from public.profiles p join auth.users u on u.id = p.id
    order by p.created_at;
end $$;

create or replace function public.set_role(p_user uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs' using errcode = '42501'; end if;
  if p_role not in ('contributor', 'editor', 'admin') then raise exception 'Rôle inconnu'; end if;
  if p_user = auth.uid() and p_role <> 'admin' then raise exception 'Vous ne pouvez pas retirer vos propres droits'; end if;
  update public.profiles set role = p_role where id = p_user;
end $$;

-- ------------------------------------------------------------ permissions
grant usage on schema public to anon, authenticated;
grant select on public.items to anon, authenticated;
grant select, insert, delete on public.proposals to authenticated;
grant select on public.profiles to authenticated;
grant select on public.item_history to authenticated;
grant execute on function public.my_role(), public.is_editor(), public.is_admin() to anon, authenticated;
grant execute on function public.apply_changes(jsonb), public.replace_all(jsonb),
  public.review_proposal(bigint, boolean, text), public.list_users(), public.set_role(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
--  APRÈS avoir créé votre propre compte depuis le site, devenez administrateur :
--    update public.profiles set role = 'admin'
--    where id = (select id from auth.users where email = 'votre.adresse@exemple.fr');
-- ---------------------------------------------------------------------
