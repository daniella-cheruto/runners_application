# GPS Distance Accuracy on Winding Trails

## Problem

Field test on 2026-07-19 (Kanunga Waterfalls / Twin Falls trail — a winding
forest hiking route):

| Source | Distance | Time | Avg Pace |
|--------|----------|------|----------|
| Garmin watch | 6.71 km | 3:53:19 | 34:48/km |
| App (this repo) | 5.06 km | 3:53:38 | 46:08/km |

Time matches closely (19s difference). Distance is undercounted by roughly
25% (1.65 km short). This is app-side distance calculation, not a save/sync
issue — the app's own GPS path visibly cuts across turns that the Garmin
track follows.

## What's already been tried (see `.opencode/plans/improvement_plan.md`)

Two prior commits already tuned this exact problem:

- `60e4f07` "tune GPS settings for better forest tracking accuracy" — changed
  `distanceFilter` from `1m` to `5m`, accuracy threshold from `>25m` reject to
  `>50m` reject, added cold-start filtering (discard first 3 fixes), added a
  speed-jump filter (reject `>15 m/s`, faster than any runner).
- `3cb54fe` "improve GPS tracking for forest environments (Phase A + C)" —
  added a watchdog that forces a fresh GPS fix if no position update arrives
  for 60+ seconds while running.

These changes were aimed at a different symptom: GPS **jitter/noise**
causing inflated distance under dense tree canopy (multipath reflections
make a stationary or slow-moving phone's GPS fix "jump around," each jump
counted as movement). Loosening `distanceFilter` to 5m and requiring 3m of
movement before counting a delta reduces that noise-driven overcounting.

**The problem now:** that same loosening appears to cause undercounting on
genuinely winding paths. With points sampled only every 5m of straight-line
movement, sharp turns and switchbacks get approximated as straight lines
between sparse points — cutting across the curve instead of following it.
The current settings are a tradeoff between two failure modes (jitter
overcounting vs. curve undercounting), not a simple bug with one fix.

The improvement plan doc also notes (`improvement_plan.md:661`):
> `distanceFilter: 5` may be better than `10` than the plan's original
> suggestion — test in the field

— confirming this exact parameter has already been adjusted once based on
field testing, and needs to be again.

## What hasn't been tried yet

- **Phase B from the existing improvement plan (Offline GPS Caching)** is
  planned but not implemented. Not directly an accuracy fix, but relevant:
  it would cache every GPS point locally as it's recorded (SQLite), not just
  at the end of a run — useful groundwork for testing different
  post-processing approaches without needing to re-run the trail each time.
- Lowering `distanceFilter` further (e.g. 2-3m) — would follow curves more
  closely, but risks reintroducing jitter-driven overcounting that Phase A
  was written to fix. Needs field testing to see which effect dominates.
- Decoupling *sampling* from *filtering*: capture points more frequently
  (time-based, e.g. every 1-2 seconds) but apply smoothing/noise-rejection
  as a separate post-processing pass (e.g. a simple moving-average or
  Kalman-style filter) rather than filtering at capture time. More
  correct engineering approach, bigger scope than a settings tweak.
- Accepting a hard limit: phone GPS alone (no motion sensor fusion) will
  likely never match a dedicated running watch's accuracy under dense
  canopy — watches like Garmin fuse GPS with accelerometer/step data
  specifically for this scenario. Worth knowing this as a ceiling on how
  close phone-only tracking can realistically get, not something a
  settings change alone can fully close.

## Why this needs field testing, not just a code review

Every previous attempt at this class of bug was a real, reasonable change
that didn't fully solve it — that's a sign confidence here can only come
from re-testing the same (or a similarly winding) trail after each change
and comparing against a real GPS watch, not from reading the code and
guessing. Any fix attempt should be tested on an actual run before being
considered done.
