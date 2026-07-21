# Run Tracking Doesn't Survive Leaving the Screen or App Kill

## Problem

Discovered while testing the Bug A fix (silent save failure): navigating
away from the run tracking screen mid-run discards the entire run — there's
no way to leave and come back to an in-progress run.

Root cause: `RunController` is created fresh in `GpsRunScreen`'s
`initState()` and disposed in `dispose()` (`lib/views/run/gps_run_screen.dart:20-34`).
All tracking state — `_distanceMeters`, `_elapsed`, `_positions`,
`_startedAt`, etc. — lives only in that one instance, in memory, for as
long as that specific screen widget is mounted. Nothing persists it
anywhere else.

## Why this matters

This isn't a security issue, but it's a real reliability/data-loss problem
for a fitness tracking app:
- Accidentally hitting the back button mid-run loses the whole run, no
  confirmation prompt, no recovery.
- If Android kills the app process in the background (common when memory
  is tight and the app isn't in the foreground) during a long run, the
  entire tracked run is gone — potentially 30+ minutes of GPS data and
  distance, with zero way to recover it.
- No warning to the user that this can happen.

## Related existing work

`.opencode/plans/improvement_plan.md` already proposes "Phase B — Add
Offline GPS Caching" (SQLite, caching GPS points to sync to Supabase when
back online). That's adjacent infrastructure (a local database for run
data) but solves a different problem — it's about syncing already-recorded
points when the network comes back, not about surviving the screen/process
being destroyed mid-run. The two could share a similar approach (local
persistence layer) but aren't the same fix.

## Possible approaches (not yet decided or implemented)

1. **Periodically persist tracking state locally** (e.g. `SharedPreferences`
   for scalar state like distance/elapsed/start time, plus a local DB for
   GPS points) so that on next app launch, the app can detect an
   in-progress run and offer to resume or at least recover what was
   tracked. Doesn't prevent the loss on its own — recovers from it.
2. **Move `RunController` out of the screen's lifecycle** into an
   app-level singleton/provider that isn't tied to one widget's lifetime —
   fixes the "accidentally hit back" case since the controller would
   survive screen navigation. Doesn't protect against the OS killing the
   whole app process while backgrounded, since an in-memory singleton is
   wiped along with the process.
3. **Proper Android foreground service for location tracking** — what
   dedicated running/fitness apps typically use. Keeps tracking alive
   independent of the Flutter UI and survives backgrounding properly.
   Significant scope: requires a persistent notification, service
   lifecycle management, and likely a plugin like
   `flutter_background_service` — this is closer to a small feature
   project than a quick fix.

Realistic order: #2 is the smallest change and fixes the most common
accidental case (back button / navigation). #1 adds recovery after an
actual kill. #3 is the real long-term fix but a much bigger undertaking —
probably future work, not near-term.

## Testing note

Like the GPS accuracy issue, this can't be fully verified by reading code —
confirming a fix means actually backgrounding/force-closing the app mid-run
on a real device and checking what happens, not just reasoning about it.
