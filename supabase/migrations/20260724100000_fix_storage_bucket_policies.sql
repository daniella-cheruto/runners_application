-- Fix: three issues found on storage.objects policies for the
-- incident-photos and profile-images buckets, found while investigating
-- a Security Advisor "public bucket allows listing" warning.



-- The app never calls storage delete on either bucket (confirmed via
-- grep across lib/ — only uploads exist), so tightening these has no
-- functional impact on the app today. Photo display in the app uses
-- getPublicUrl(), which is served through a separate public-bypass
-- endpoint that doesn't consult these policies, so restricting SELECT to
-- authenticated only closes the listing/browsing gap, not normal viewing.

alter policy "Allow public read of incident photos 1cuy8kc_0"
on storage.objects
to authenticated;

alter policy "Allow public read access vejz8c_0"
on storage.objects
to authenticated;

alter policy "Allow users to delete incident photos 1cuy8kc_0"
on storage.objects
to authenticated
using (bucket_id = 'incident-photos' and owner = auth.uid());

alter policy "Allow deletes for authenticated users vejz8c_0"
on storage.objects
to authenticated
using (bucket_id = 'profile-images' and owner = auth.uid());
