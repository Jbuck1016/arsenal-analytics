delete from team_names
where league = 'INT-Champions League'
  and event_name = 'Bayer Leverkusen'
  and match_name = 'Bayer Leverkusen';

select league, match_name, count(*)::text as n
from team_names group by league, match_name having count(*) > 1;
