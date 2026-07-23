-- Fix: the "Admins can read all profiles" policy added in
-- 20260723090200_restrict_profiles_view_and_admin_policy.sql caused
-- "infinite recursion detected in policy" (Postgres error 42P17) — it
-- checked admin status by querying profiles directly from within a
-- policy on profiles itself, which re-triggers the same policy
-- evaluation forever. Because several other tables' admin-check
-- policies also query profiles the same way, this broke nearly every
-- screen in the app (routes, run history, feedback, incidents), not
-- just profiles.
--
-- Fix: move the admin check into a security definer function, which
-- bypasses RLS internally and breaks the recursive loop.

drop policy if exists "Admins can read all profiles" on public.profiles;

create or replace function public.is_current_user_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce(
    (select is_admin from public.profiles where id = auth.uid()),
    false
  );
$$;

create policy "Admins can read all profiles"
on public.profiles
for select
to authenticated
using (public.is_current_user_admin());
