-- Fix: route_feedback and route_photos SELECT policies were scoped to
-- {public} instead of {authenticated} — inconsistent with routes itself
-- requiring {authenticated} to read at all. This let anyone query
-- ratings, comments, and approved photo URLs via the REST API without
-- ever creating an account, bypassing the login requirement entirely.

alter policy "Route feedback is readable by all users" on public.route_feedback to authenticated;

alter policy "Public read approved route photos" on public.route_photos to authenticated;
