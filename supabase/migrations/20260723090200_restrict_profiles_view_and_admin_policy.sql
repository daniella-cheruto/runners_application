-- Fix: "Allow read of public profiles" RLS policy on public.profiles was
-- too broad — any authenticated user could read every other user's dob,
-- emergency_contact (phone number), and is_admin flag, not just
-- public-facing fields.
--
-- Fix: create a restricted view exposing only safe columns, drop the
-- broad policy, and add a dedicated admin SELECT policy so the admin
-- Users screen (which lists every profile) keeps working — it was
-- previously relying entirely on the broad policy being removed here.

create or replace view public.public_profiles as
select id, full_name, profile_image_url
from public.profiles;

grant select on public.public_profiles to authenticated;

create policy "Admins can read all profiles"
on public.profiles
for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_admin = true
  )
);

drop policy if exists "Allow read of public profiles" on public.profiles;
