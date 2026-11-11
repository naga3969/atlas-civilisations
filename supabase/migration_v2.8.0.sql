-- =====================================================================
--  Atlas des civilisations — migration v2.8.0
--  À exécuter dans Supabase › SQL Editor AVANT de publier index.html v2.8.0.
--  Rejouable sans risque : chaque instruction remplace ou recrée à l'identique.
--
--  Ajoute à la base les collections « persons » (personnages, v2.4.0)
--  et « dynasties » (v2.8.0). Les faits de vie, la filiation des
--  personnages et les autres nouveautés sont de simples champs des
--  éléments existants : rien d'autre à changer.
-- =====================================================================

-- 1. collections acceptées par la table des éléments
do $$
declare c record;
begin
  for c in
    select conname from pg_constraint
    where conrelid = 'public.items'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ilike '%coll%'
  loop
    execute format('alter table public.items drop constraint %I', c.conname);
  end loop;
end $$;

alter table public.items add constraint items_coll_check
  check (coll in ('civs', 'territories', 'events', 'pois', 'links', 'subjections', 'persons', 'dynasties'));

-- 2. remplacement complet (administrateurs) : prend aussi les nouvelles collections
create or replace function public.replace_all(p_db jsonb)
returns integer language plpgsql security definer set search_path = public as $$
declare k text; o jsonb; n integer := 0;
begin
  if not public.is_admin() then raise exception 'Réservé aux administrateurs' using errcode = '42501'; end if;
  delete from public.items where true;
  foreach k in array array['civs', 'territories', 'events', 'pois', 'links', 'subjections', 'persons', 'dynasties'] loop
    for o in select * from jsonb_array_elements(coalesce(p_db->k, '[]'::jsonb)) loop
      insert into public.items (coll, id, data, updated_by) values (k, o->>'id', o, auth.uid());
      n := n + 1;
    end loop;
  end loop;
  return n;
end $$;

grant execute on function public.replace_all(jsonb) to authenticated;

-- 3. contrôle
select 'migration v2.8.0 appliquée' as statut,
       pg_get_constraintdef(oid) as collections
from pg_constraint where conrelid = 'public.items'::regclass and conname = 'items_coll_check';
