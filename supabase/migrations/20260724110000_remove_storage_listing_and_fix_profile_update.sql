-- Follow-up to 20260724100000_fix_storage_bucket_policies.sql.
-- Removes listing/browsing entirely for incident-photos, profile-images,
-- and route-photos (public buckets don't need this — viewing a specific
-- file already works through a separate mechanism that doesn't use these
-- policies). Also adds the missing ownership check to profile-images'
-- UPDATE policy, matching the same fix already applied to its DELETE
-- policy. See SECURITY_TODO.md for full details.

drop policy if exists "Allow public read of incident photos 1cuy8kc_0" on storage.objects;
drop policy if exists "Allow public read access vejz8c_0" on storage.objects;
drop policy if exists "Public read route photos" on storage.objects;

alter policy "Allow updates for authenticated users vejz8c_0"
on storage.objects
to authenticated
using (bucket_id = 'profile-images' and owner = auth.uid());
