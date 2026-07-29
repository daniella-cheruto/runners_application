-- Follow-up to 20260724110000_remove_storage_listing_and_fix_profile_update.sql.
-- That migration dropped SELECT policies to stop public listing, but this
-- also silently broke each bucket's own delete feature (storage needs
-- SELECT access to find a file before deleting it). Adds back a narrow
-- SELECT policy per bucket, scoped to owner = auth.uid(), so users can find
-- and delete their own files without reopening public browsing.

create policy "Users can view their own incident photos"
on storage.objects
for select
to authenticated
using (bucket_id = 'incident-photos' and owner = auth.uid());

create policy "Users can view their own route photos"
on storage.objects
for select
to authenticated
using (bucket_id = 'route-photos' and owner = auth.uid());

create policy "Users can view their own profile images"
on storage.objects
for select
to authenticated
using (bucket_id = 'profile-images' and owner = auth.uid());
