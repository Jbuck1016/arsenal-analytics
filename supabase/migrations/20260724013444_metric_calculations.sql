alter table public.metric_defs add column if not exists calc text;

update public.metric_defs set calc = v.c from (values
 ('pass_cmp_90','Count events where type = Pass, outcome = Successful, set pieces excluded. Divided by minutes/90.'),
 ('pass_pct','Completed open-play passes divided by attempted, as a percentage.'),
 ('prog_cmp_90','A pass counts as progressive if it moves the ball at least 30 units toward goal inside the own half, 15 across halves, or 10 inside the opposition half. Completed only, per 90.'),
 ('prog_pct','Completed progressive passes divided by attempted. Suppressed below 25 attempts because the rate is unstable.'),
 ('territory_90','For each completed pass, the forward distance gained, scaled to metres (pitch length 105m). Backward passes count zero. Summed, then per 90.'),
 ('into_box_90','Completed passes whose end point falls inside the penalty area, per 90.'),
 ('final_third_90','Completed passes ending beyond two-thirds of the pitch length, per 90.'),
 ('through_90','Passes carrying the provider''s Throughball qualifier, per 90.'),
 ('cross_90','Passes carrying the Cross qualifier, set pieces excluded, per 90.'),
 ('cross_pct','Completed crosses over attempted. Needs 20 attempts.'),
 ('key_pass_90','Passes carrying the KeyPass qualifier, meaning the next action was a shot, per 90.'),
 ('assist_90','Passes carrying the IntentionalGoalAssist qualifier, per 90.'),
 ('bcc_90','Passes carrying the BigChanceCreated qualifier, per 90.'),
 ('xa_90','For every shot, we look at the pass immediately before it. If that pass was a key pass, its player is credited with the shot''s xG. Summed, then per 90.'),
 ('xt_90','The pitch is a 12x8 grid, each cell holding a threat value. Every completed pass and carry earns the difference between its end cell and its start cell. Summed, then per 90.'),
 ('xt_pass_90','As xT added, counting passes only.'),
 ('xt_carry_90','As xT added, counting carries only.'),
 ('sca_90','The two on-ball actions immediately preceding a shot, credited to distinct team-mates, per 90.'),
 ('shots_90','Open-play shot events (saved, blocked, off target, post, goal), per 90.'),
 ('sot_90','Shots that reached the keeper: saved plus scored. Blocked attempts are excluded even though the provider files them as saves.'),
 ('goals_90','Goal events, own goals removed, per 90.'),
 ('xg_90','Every shot is placed in a bin by distance, angle to the goal mouth, header or not, and big-chance flag. The bin''s conversion rate in this season is its xG, pulled toward the league mean so thin bins behave. Penalties fixed at 0.76.'),
 ('xg_per_shot','Total xG divided by shots. Measures the quality of positions he gets into rather than volume.'),
 ('finishing','Goals minus expected goals, per 90. Positive means he is scoring more than his chances merit.'),
 ('box_share','Shots taken inside the penalty area as a share of all his shots.'),
 ('shot_dist','Straight-line distance from the centre of the goal to the shot, averaged, in metres.'),
 ('conversion','Goals divided by shots. Needs 12 shots.'),
 ('shot_acc','On-target shots over total shots, blocks excluded.'),
 ('blocked_90','His own shots stopped by a defender before reaching the keeper, per 90.'),
 ('weak_foot_share','Of shots where a foot is recorded, the share taken with the less-used foot. 50% means genuinely two-footed.'),
 ('carries_90','Carries are not recorded by the provider. We infer them: where the ball arrived to a player and where his next action began. Movements of 3m or more count. Per 90.'),
 ('prog_carries_90','Carries that cut the distance to goal by more than 15%, per 90.'),
 ('carry_box_90','Carries ending inside the penalty area having started outside it, per 90.'),
 ('mean_carry_m','Average length of a carry in metres.'),
 ('carry_pen_90','Metres of distance-to-goal eliminated by progressive carries, per 90.'),
 ('median_ttr','Seconds between the ball arriving and the player releasing it, taken as the median across every receipt.'),
 ('quick_pct','Share of passes released inside two seconds of receiving.'),
 ('one_touch_pct','Share of passes released inside one second.'),
 ('tackle_90','Tackle events per 90, won or lost.'),
 ('tackle_pct','Tackles won over attempted. Needs 15 attempts.'),
 ('int_90','Interception events per 90.'),
 ('clear_90','Clearance events per 90.'),
 ('block_90','Blocked passes per 90.'),
 ('recov_90','Loose balls won per 90.'),
 ('aerial_90','Aerial duels contested per 90.'),
 ('aerial_pct','Aerial duels won over contested. Needs 20 duels.'),
 ('def_action_90','Tackles, interceptions, clearances, blocks and recoveries combined, per 90.'),
 ('def_height','Mean pitch position of his defensive actions, on a 0-100 scale where 100 is the opposition goal.'),
 ('padj_def_90','Defensive actions scaled by 50 divided by the possession his team concedes. A defender at a dominant side gets fewer chances to defend, and this corrects for it.'),
 ('padj_tackle_90','Tackles, possession-adjusted the same way.'),
 ('padj_int_90','Interceptions, possession-adjusted.'),
 ('padj_recov_90','Recoveries, possession-adjusted.'),
 ('counterpress_90','Defensive actions made within five seconds of his team losing the ball, per 90.'),
 ('box_def_90','Defensive actions inside his own penalty area, per 90.'),
 ('channel_def_90','Defensive actions in the half-space channels of his own half, per 90.'),
 ('flank_def_90','Defensive actions in the wide areas of his own half, per 90.'),
 ('takeon_90','Attempted dribbles past an opponent, per 90.'),
 ('takeon_pct','Take-ons completed over attempted. Needs 15 attempts.'),
 ('disp_90','Times the ball was taken off him, per 90.'),
 ('badtouch_90','Miscontrols per 90.'),
 ('aq_per_duel','For each aerial he wins we follow the next event: 2 points if he keeps it himself, 1 if it drops to a team-mate, minus 1 if the opposition get it. Averaged over duels won.'),
 ('duel_quality','Of the aerials he wins, the share where the ball stays with his own side. Needs 10 wins.'),
 ('recov_retention','After winning the ball back, the completion rate of his next pass. Needs 10 attempts.'),
 ('recov_prog_90','Completed progressive passes played immediately off a ball recovery, per 90.'),
 ('hs_passes_90','The half-spaces are the two strips between the edge of the penalty area and the six-yard line extended. Passes played from those strips in the attacking half, per 90.'),
 ('hs_prog_90','Completed progressive passes from the half-space, per 90.'),
 ('hs_key_90','Shot-creating passes from the half-space, per 90.'),
 ('hs_shots_90','Shots taken from the half-space strips, per 90.'),
 ('hs_takeons_90','Take-ons attempted in the half-space, per 90.'),
 ('holds_90','Times he kept the ball five seconds or more in the final third, per 90.'),
 ('hold_retention','Share of those holds where his team still had the ball afterwards.'),
 ('hold_prog_pct','Share of holds he ended by carrying meaningfully forward.'),
 ('hold_shot_pct','Share of holds ending in his own shot.'),
 ('sp_xg_90','A set-piece phase is the ten seconds after a dead-ball delivery. xG from shots inside those phases, per 90. Throw-ins count as deliveries.'),
 ('sp_shots_90','Shots taken inside set-piece phases, per 90.'),
 ('sp_aerials_90','Aerial duels won inside set-piece phases, per 90.'),
 ('sp_key_90','Dead-ball deliveries that created a shot, per 90.'),
 ('save_pct','Saves over shots on target faced. Needs 15 faced.'),
 ('goals_prevented_90','xG of the shots on target he faced, minus goals conceded, per 90. Positive means he saves more than the chances merited.'),
 ('saves_90','Save events per 90.'),
 ('claims_90','Crosses claimed per 90.'),
 ('sweeps_90','Actions outside his box to cut out a through ball, per 90.'),
 ('sweep_x','Mean pitch position of those sweeping actions. Higher means a higher defensive line behind him.'),
 ('foul_com_90','Fouls conceded per 90.'),
 ('foul_won_90','Fouls drawn per 90.'),
 ('error_90','Errors leading to an opposition chance, per 90.')
) as v(k,c) where metric_defs.key = v.k;

-- League context and a named example at each end of the range
create materialized view mv_metric_examples as
with q as (
  select p.metric, p.pool, p.player_id, p.value, p.pct, s.player_name, s.team, s.nineties
  from mv_player_percentiles p
  join mv_player_season s using (player_id)
  where s.nineties >= 8
),
stat as (
  select metric,
    count(*) as n,
    round(min(value)::numeric,3)  as min_v,
    round(percentile_cont(0.5) within group (order by value)::numeric,3) as med_v,
    round(max(value)::numeric,3)  as max_v
  from q group by metric
),
hi as (select distinct on (metric) metric, player_id, player_name, team, pool, value, nineties
       from q order by metric, value desc),
lo as (select distinct on (metric) metric, player_id, player_name, team, pool, value, nineties
       from q order by metric, value asc)
select st.metric, st.n, st.min_v, st.med_v, st.max_v,
  hi.player_name as hi_name, hi.team as hi_team, hi.pool as hi_pool,
  round(hi.value::numeric,3) as hi_value, hi.player_id as hi_id,
  lo.player_name as lo_name, lo.team as lo_team, lo.pool as lo_pool,
  round(lo.value::numeric,3) as lo_value, lo.player_id as lo_id
from stat st
left join hi on hi.metric = st.metric
left join lo on lo.metric = st.metric;
create unique index on mv_metric_examples (metric);
grant select on mv_metric_examples to anon, authenticated;
notify pgrst, 'reload schema';
