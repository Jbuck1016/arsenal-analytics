
create extension if not exists pg_trgm;
create extension if not exists unaccent;

-- Phrase -> metric mapping. A scout types football language, not column names.
drop table if exists public.metric_synonyms cascade;
create table public.metric_synonyms (
  phrase text primary key,
  metric text,          -- single metric, or null when the phrase means a whole family
  grp text,             -- metric_catalog group, for family phrases
  weight int default 1
);
insert into public.metric_synonyms (phrase, metric, grp) values
 -- threat
 ('expected threat', null, 'Threat'), ('threat', null, 'Threat'), ('xt', null, 'Threat'),
 ('threat creation', null, 'Threat'), ('expected threat creation', null, 'Threat'),
 ('threat from passing','xt_pass_90',null), ('passing threat','xt_pass_90',null),
 ('threat from carrying','xt_carry_90',null), ('carrying threat','xt_carry_90',null),
 -- progression
 ('progression', null, 'Progression'), ('ball progression', null, 'Progression'),
 ('progressive passing','prog_cmp_90',null), ('progressive passes','prog_cmp_90',null),
 ('passes into the box','into_box_90',null), ('box entries','into_box_90',null),
 ('through balls','through_90',null), ('long passing','long_90',null),
 -- carrying
 ('carrying', null, 'Carrying'), ('ball carrying', null, 'Carrying'), ('carries', null, 'Carrying'),
 ('dribbling','takeon_90',null), ('take ons','takeon_90',null), ('take-ons','takeon_90',null),
 ('one v one','takeon_90',null), ('1v1','takeon_90',null),
 ('progressive carries','prog_carries_90',null), ('carries into the box','carry_box_90',null),
 -- creation
 ('creation', null, 'Creation'), ('chance creation', null, 'Creation'), ('creativity', null, 'Creation'),
 ('key passes','key_pass_90',null), ('assists','assist_90',null),
 ('expected assists','xa_90',null), ('xa','xa_90',null),
 ('crossing','cross_90',null), ('crosses','cross_90',null),
 ('big chances created','bcc_90',null),
 -- shooting
 ('shooting', null, 'Shooting'), ('finishing', null, 'Shooting'), ('goalscoring', null, 'Shooting'),
 ('goals','goals_90',null), ('shots','shots_90',null),
 ('expected goals','xg_90',null), ('xg','xg_90',null),
 ('shot quality','xg_per_shot',null), ('conversion','conversion',null),
 -- defending
 ('defending', null, 'Defending'), ('defensive work', null, 'Defending'),
 ('tackling','tackle_90',null), ('tackles','tackle_90',null),
 ('interceptions','int_90',null), ('recoveries','recov_90',null),
 ('aerials','aerial_90',null), ('aerial ability','aerial_90',null),
 ('pressing','counterpress_90',null), ('counterpressing','counterpress_90',null),
 -- passing / trajectory / chain
 ('passing', null, 'Passing'), ('distribution', null, 'Passing'),
 ('pass trajectory', null, 'Trajectory'), ('trajectory', null, 'Trajectory'),
 ('balls over the top','pct_over',null), ('playing in behind','pct_in_behind',null),
 ('chain involvement', null, 'Chain value'), ('build up involvement', null, 'Chain value'),
 ('early involvement','early_shot_inv_90',null), ('deep involvement','early_shot_inv_90',null);

grant select on public.metric_synonyms to anon, authenticated;

-- Resolve a typed name to a player. Trigram similarity handles misspellings and
-- missing accents ("hector herrera" -> "Héctor Herrera").
create or replace function public.resolve_player(p_name text)
returns table(player_id text, player text, team text, pos text, score real)
language sql stable set search_path = public as $fn$
  select ps.player_id, ps.player, ps.team, ps.pos,
         similarity(unaccent(lower(ps.player)), unaccent(lower(p_name))) as score
  from public.player_search ps
  where unaccent(lower(ps.player)) % unaccent(lower(p_name))
     or unaccent(lower(ps.player)) like '%'||unaccent(lower(p_name))||'%'
  order by score desc, ps.nineties desc nulls last
  limit 5;
$fn$;
grant execute on function public.resolve_player(text) to anon, authenticated;

create index if not exists player_search_name_trgm
  on public.player_search using gin (player gin_trgm_ops);
