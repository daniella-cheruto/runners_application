# Future Feature: A Way for Users to Reach Admins

## Where this came from

While adding the delete-route feature, the blocked-delete message
originally said "contact an admin if it needs to be removed" — but there's
no actual in-app way to do that today. No support form, no messaging
feature, no flagging mechanism. The wording was removed since it pointed
to a dead end, but the underlying need is real: admins already have
moderation powers in this app (`adminDeleteRoute`, `adminDeleteFeedback`,
`adminDeleteIncident`, user account management), there's just no channel
for a regular user to ask them to act.

## The gap

Right now, if a user hits a case where they need admin intervention —
e.g. a route with attached community data that they can't self-delete, a
feedback comment they think should be removed, an incident report that
needs review — there's no way to flag it from within the app. They'd have
to reach an admin through some channel entirely outside the app (if they
even know who that is).

## Rough shape of a possible feature (not designed in detail yet)

- A simple "Report" or "Flag for admin review" action on routes, feedback,
  or incidents — writes a row to some kind of `admin_reports` /
  `moderation_queue` table (route/feedback/incident ID, reporter,
  reason, timestamp).
- Admin dashboard already exists (`admin_home_screen.dart` and related
  admin controllers) — this would just need a new section listing pending
  reports for admins to act on, reusing the existing admin-only RLS
  pattern already established for other admin tables.
- Simpler alternative: a basic "Contact support" screen with a static
  email/contact method, no database-backed queue — much smaller scope,
  but no tracking/history of requests.

## Status

Not started. This is a placeholder for a future feature, not an active
bug or security issue. Revisit when there's appetite for a moderation/
reporting feature.
