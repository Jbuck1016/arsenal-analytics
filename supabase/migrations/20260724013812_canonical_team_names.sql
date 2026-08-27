-- WhoScored uses short names in the event feed and full names in the schedule.
-- One table reconciles them so nothing has to guess again.
create table if not exists public.team_names (
  event_name   text primary key,   -- as it appears in events.team
  match_name   text not null,      -- as it appears in matches.home_team / away_team
  display_name text not null       -- what a human should see
);
truncate public.team_names;
insert into public.team_names (event_name, match_name, display_name) values
 ('Chicago','Chicago Fire FC','Chicago Fire FC'),
 ('Colorado','Colorado Rapids','Colorado Rapids'),
 ('Columbus','Columbus Crew','Columbus Crew'),
 ('Houston','Houston Dynamo FC','Houston Dynamo FC'),
 ('Kansas City','Sporting Kansas City','Sporting Kansas City'),
 ('L.A. Galaxy','LA Galaxy','LA Galaxy'),
 ('Montreal','CF Montreal','CF Montréal'),
 ('New England','New England Revolution','New England Revolution'),
 ('New York','Red Bull New York','New York Red Bulls'),
 ('Philadelphia','Philadelphia Union','Philadelphia Union'),
 ('Portland','Portland Timbers','Portland Timbers'),
 ('Salt Lake','Real Salt Lake','Real Salt Lake'),
 ('San Jose','San Jose Earthquakes','San Jose Earthquakes'),
 ('Seattle','Seattle Sounders FC','Seattle Sounders FC'),
 ('Toronto','Toronto FC','Toronto FC'),
 ('Vancouver','Vancouver Whitecaps','Vancouver Whitecaps'),
 ('Atlanta United','Atlanta United','Atlanta United'),
 ('Austin FC','Austin FC','Austin FC'),
 ('Charlotte FC','Charlotte FC','Charlotte FC'),
 ('DC United','DC United','D.C. United'),
 ('FC Cincinnati','FC Cincinnati','FC Cincinnati'),
 ('FC Dallas','FC Dallas','FC Dallas'),
 ('Inter Miami CF','Inter Miami CF','Inter Miami CF'),
 ('Los Angeles FC','Los Angeles FC','Los Angeles FC'),
 ('Minnesota United','Minnesota United','Minnesota United'),
 ('Nashville SC','Nashville SC','Nashville SC'),
 ('New York City FC','New York City FC','New York City FC'),
 ('Orlando City','Orlando City','Orlando City'),
 ('San Diego FC','San Diego FC','San Diego FC'),
 ('St. Louis City','St. Louis City','St. Louis City');

grant select on public.team_names to anon, authenticated;
notify pgrst, 'reload schema';
