begin;

-- Historical raw events intentionally do not enter the live sequence layer.
-- Compare the two canonical current-season league scopes as sets, in both
-- directions, so equal counts cannot conceal different game populations.
update public.invariants
set description = 'The current-season league sequence layer covers exactly the games present in current-season league events.',
    check_sql = $sql$
      select count(*)
      from (
        (
          select distinct game_id from public.v_league_events
          except
          select distinct game_id from public.v_league_sequences
        )
        union all
        (
          select distinct game_id from public.v_league_sequences
          except
          select distinct game_id from public.v_league_events
        )
      ) gaps
    $sql$
where name = 'seq_covers_events';

do $assert$
declare
  violations bigint;
begin
  if not exists (
    select 1 from public.invariants where name = 'seq_covers_events'
  ) then
    raise exception 'seq_covers_events invariant is missing';
  end if;

  execute (
    select check_sql
    from public.invariants
    where name = 'seq_covers_events'
  ) into violations;

  if violations <> 0 then
    raise exception 'current-season sequence coverage has % mismatched game(s)', violations;
  end if;
end
$assert$;

commit;
