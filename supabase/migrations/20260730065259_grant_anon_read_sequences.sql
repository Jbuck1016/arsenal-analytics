
grant select on public.sequences to anon, authenticated;
grant select on public.team_sequence_agg to anon, authenticated;
grant select on public.team_sequence_style to anon, authenticated;
grant select on public.seq_fz to anon, authenticated;
grant execute on function public.similar_sequences(text,int) to anon, authenticated;
grant execute on function public.similar_teams(text,int) to anon, authenticated;
grant execute on function public.top_sequences_by_type(text,int) to anon, authenticated;
