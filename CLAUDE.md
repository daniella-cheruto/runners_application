# Runners Application — Claude Guidelines

## About the Project
A Flutter running tracker app for Nairobi trail runners. Users can browse routes, track GPS runs, leave route feedback, report safety incidents, and upload photos. Admins can manage routes, users, feedback, and incidents. Backend is Supabase (PostgreSQL + Auth + Storage).

## Before Making Any Change

Answer these questions before writing or suggesting code:

### 1. Is this built in the most secure way?
- Are we exposing any sensitive data (API keys, URLs, user data)?
- Could this introduce SQL injection, XSS, or unauthorized data access?
- Are Supabase RLS policies respected — does the code assume the client enforces security?
- Are we validating input at system boundaries?

### 2. Is this built in the most efficient way?
- Are we making unnecessary Supabase requests?
- Are we rebuilding widgets that don't need to rebuild?
- Are we loading more data than needed (missing `.limit()`, missing filters)?
- Are images cached or fetched fresh every time?

### 3. What regressions could this introduce?
- Does this change affect other screens that share the same controller or data?
- Could this break the GPS tracking flow (start → pause → resume → stop)?
- Could this affect the admin screens if the change is in a shared controller?
- Does this change the Supabase query structure in a way that could break existing data?

### 4. What tests do we need to write before shipping this?
- Does this change have a controller method that should be unit tested?
- Is there a user flow that should be integration tested?
- Has this been manually tested on a real device (especially GPS changes)?

## Creating a New Supabase Table

Since Oct 30, 2026, Supabase no longer grants default Data API access to new tables in `public` — a table with no explicit `GRANT` is invisible to `supabase-js`/PostgREST/GraphQL even with RLS off. Tables are still created directly in the dashboard SQL editor (not via the Supabase CLI), but every change should also be saved as a new file in `supabase/migrations/` (format: `YYYYMMDDHHMMSS_description.sql`) so there's a permanent record in the repo — run this template every time, before shipping any feature that relies on the new table:

```sql
-- Grant access per role
grant select
  on public.your_table
  to anon;

grant select, insert, update, delete
  on public.your_table
  to authenticated;

grant select, insert, update, delete
  on public.your_table
  to service_role;

-- Enable RLS
alter table public.your_table
  enable row level security;

-- Add policies
create policy "users can read their own rows"
  on public.your_table
  for select to authenticated
  using (auth.uid() = user_id);
```

Adjust role grants and policies to the table's actual access pattern (e.g. admin-only tables shouldn't grant `anon`). If PostgREST returns a `42501` error, it names the missing grant directly.

## Git Workflow
- Work on `dev` branch, PR into `main`
- After merging to main: `git pull origin main` → `git push backup main` → `git checkout dev`
- PRs always on `daniella-cheruto/runners_application` (origin), never on backup

## Architecture
- Controllers: `lib/controllers/` — business logic, direct Supabase calls
- Views: `lib/views/` — organized by feature (auth, run, home, feedback, incident, admin, profile)
- Models: `lib/models/` — data models
- Widgets: `lib/widgets/` — shared reusable widgets
- No repository layer yet (planned refactor)
- State management: `ChangeNotifier` for `RunController`, plain classes for others
