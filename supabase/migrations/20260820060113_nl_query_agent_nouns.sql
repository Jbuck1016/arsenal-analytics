
-- Scouts describe players with agent nouns ("as a shooter", "as a progressive passer"),
-- not metric names. Longest matching phrase wins, so "progressive passer" beats "passer".
insert into public.metric_synonyms (phrase, metric, grp, rank_metric) values
 -- shooting
 ('shooter', null, 'Shooting', 'xg_90'),
 ('finisher', null, 'Shooting', 'xg_90'),
 ('goalscorer', null, 'Shooting', 'goals_90'),
 ('goal scorer', null, 'Shooting', 'goals_90'),
 ('poacher','box_threat',null,null),
 ('penalty box striker','box_threat',null,null),
 ('shot taker', null, 'Shooting', 'shots_90'),
 -- passing / progression
 ('passer', null, 'Passing', 'pass_cmp_90'),
 ('progressive passer','prog_cmp_90',null,null),
 ('progressor','prog_cmp_90',null,null),
 ('deep lying playmaker','prog_cmp_90',null,null),
 ('deep-lying playmaker','prog_cmp_90',null,null),
 ('key passer','key_pass_90',null,null),
 ('line breaker','through_90',null,null),
 ('line-breaker','through_90',null,null),
 ('long passer','long_90',null,null),
 ('switcher','long_90',null,null),
 ('crosser','cross_90',null,null),
 ('distributor', null, 'Passing', 'pass_cmp_90'),
 -- creation
 ('creator', null, 'Creation', 'xa_90'),
 ('chance creator', null, 'Creation', 'xa_90'),
 ('assister','assist_90',null,null),
 ('number 10', null, 'Creation', 'xa_90'),
 -- carrying / dribbling
 ('carrier', null, 'Carrying', 'prog_carries_90'),
 ('ball carrier', null, 'Carrying', 'prog_carries_90'),
 ('dribbler','takeon_90',null,null),
 ('runner', null, 'Carrying', 'prog_carries_90'),
 ('take on merchant','takeon_90',null,null),
 -- defending
 ('defender', null, 'Defending', 'def_action_90'),
 ('tackler','tackle_90',null,null),
 ('interceptor','int_90',null,null),
 ('presser','counterpress_90',null,null),
 ('ball winner', null, 'Defending', 'def_action_90'),
 ('destroyer', null, 'Defending', 'def_action_90'),
 ('aerial threat','aerial_90',null,null),
 ('header of the ball','aerial_90',null,null),
 -- threat / chain
 ('threat creator', null, 'Threat', 'xt_90'),
 ('build up player', null, 'Chain value', 'early_shot_inv_90'),
 ('build-up player', null, 'Chain value', 'early_shot_inv_90'),
 ('chain starter','early_shot_inv_90',null,null),
 ('tempo setter','role_controller',null,null)
on conflict (phrase) do update set metric=excluded.metric, grp=excluded.grp,
  rank_metric=excluded.rank_metric;

-- 'tempo setter' points at a chain role rather than a metric_catalog key; drop the
-- rank_metric so it cannot be used as a ranking axis it does not support.
update public.metric_synonyms set metric=null, grp='Chain value', rank_metric='early_shot_inv_90'
  where phrase='tempo setter';
