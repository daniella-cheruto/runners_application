-- Fix: "Allow rating updates" RLS policy on public.routes was too broad —
-- any authenticated user could rewrite any column of any route, not just
-- submit a rating. Move stats computation into a trigger, then drop the
-- broad policy.

create or replace function public.recompute_route_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target_route_id int;
  stats record;
begin
  target_route_id := coalesce(new.route_id, old.route_id);

  select coalesce(avg(rating), 0) as avg_rating, count(*) as feedback_count
  into stats
  from public.route_feedback
  where route_id = target_route_id;

  update public.routes
  set
    average_rating = stats.avg_rating,
    popularity = stats.feedback_count
  where route_id = target_route_id;

  return coalesce(new, old);
end;
$$;

drop trigger if exists route_feedback_stats_trigger on public.route_feedback;

create trigger route_feedback_stats_trigger
after insert or update or delete on public.route_feedback
for each row execute function public.recompute_route_stats();

drop policy if exists "Allow rating updates" on public.routes;
