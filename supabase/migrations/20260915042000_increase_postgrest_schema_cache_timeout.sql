-- The public analytics schema takes longer than the previous eight-second
-- window to introspect after a cold PostgREST schema-cache rebuild.
alter role authenticator set statement_timeout = '30s';
