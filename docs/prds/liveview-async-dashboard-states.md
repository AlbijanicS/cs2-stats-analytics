# PRD: LiveView Local-First Async Dashboard States

## Problem Statement

Players can search for a FACEIT nickname and view a CS2 analytics dashboard backed by imported local database rows, but the dashboard loading experience is still too blunt. A search can clear the existing dashboard and show a generic loading state even when usable cached dashboard data already exists. That will feel broken once the app moves from the fake FACEIT client to the real FACEIT API, where fetches can be slow, fail, or be rate-limited.

The user needs the dashboard to feel responsive and trustworthy: show cached stats immediately when they exist, make background refresh work visible, and preserve old dashboard data when a refresh fails.

## Solution

Implement a local-first LiveView search flow with explicit dashboard states. `Analytics` will own freshness classification and expose a public refresh-state API. `PlayerDashboardLive` will use that API to decide whether to render fresh local data immediately, show stale local data while starting an async refresh, or load a missing profile asynchronously. Async success replaces the dashboard; async failure either shows a blocking error when no dashboard exists or a non-destructive error while keeping cached dashboard data visible.

The slice keeps the current architecture boundary intact: LiveView calls only public `Analytics` functions. `Analytics` continues coordinating local reads, sync decisions, FACEIT client access, normalization, importing, and database reads.

## User Stories

1. As a CS2 player, I want the dashboard page to start in an empty state, so that I can search for a FACEIT nickname without seeing stale or misleading data.
2. As a CS2 player, I want to enter a FACEIT nickname and submit the search form, so that I can request recent FACEIT performance stats.
3. As a CS2 player, I want blank nickname searches to show a friendly validation error, so that I know what to fix.
4. As a CS2 player, I want a missing local profile to show a loading message, so that I know the app is fetching stats.
5. As a CS2 player, I want the loading message to have a stable DOM target, so that the behavior can be tested and trusted.
6. As a CS2 player, I want a successful first search to render the dashboard summary, latest match, charts, and recent matches, so that I can inspect my recent performance.
7. As a CS2 player, I want an unknown FACEIT nickname to show a friendly error, so that I understand the player was not found.
8. As a CS2 player, I want missing recent match history to show a friendly error, so that I understand why the dashboard cannot be shown yet.
9. As a CS2 player, I want match-stat fetch failures to show a friendly error, so that I understand the dashboard could not be completed.
10. As a CS2 player, I want a fresh cached dashboard to appear immediately, so that repeated searches do not feel slow.
11. As a CS2 player, I want fresh cached dashboard rows to avoid unnecessary FACEIT client calls, so that the app stays fast and avoids future rate-limit pressure.
12. As a CS2 player, I want a dashboard with fewer local rows than the requested limit to remain valid when still fresh, so that valid local data is not discarded prematurely.
13. As a CS2 player, I want stale cached dashboard data to remain visible immediately, so that I can keep reading useful stats while the app refreshes.
14. As a CS2 player, I want stale cached dashboard data to show an updating message or badge, so that I know a refresh is in progress.
15. As a CS2 player, I want a successful background refresh to replace the stale dashboard, so that I eventually see the newest available stats.
16. As a CS2 player, I want a failed background refresh to keep the cached dashboard visible, so that a temporary FACEIT/API failure does not erase useful data.
17. As a CS2 player, I want a failed background refresh to show a non-destructive error message, so that I know the data may not be fully current.
18. As a CS2 player, I want repeated searches to cancel in-flight dashboard loads, so that outdated search results do not waste work or overwrite newer intent.
19. As a CS2 player, I want cancellation results to stay non-user-facing, so that normal repeated searching does not show scary errors.
20. As a CS2 player, I want chart hooks to keep working after dashboard refreshes, so that trend visualizations remain available.
21. As a developer, I want `Analytics` to own freshness policy, so that the LiveView does not inspect persistence fields such as `last_synced_at`.
22. As a developer, I want `Analytics` to distinguish local dashboard reads, refresh-state classification, and sync-capable dashboard loading, so that each public API has a clear responsibility.
23. As a developer, I want the LiveView to call only public `Analytics` functions, so that UI code does not depend on FACEIT clients, normalizers, importers, schemas, or repo queries.
24. As a developer, I want async loading and refresh behavior to be covered by LiveView tests, so that future UI refactors preserve the user-visible states.
25. As a developer, I want freshness behavior covered by Analytics tests, so that the policy can evolve without breaking local-first dashboard behavior.

## Implementation Decisions

- Add a public `Analytics.get_dashboard_refresh_state/2` API.
- `Analytics.get_dashboard_refresh_state/2` returns `{:ok, :fresh, dashboard}`, `{:ok, :stale, dashboard}`, `{:error, :player_not_found}`, `{:error, :no_recent_stats}`, or `{:error, reason}`.
- `Analytics` owns the freshness policy. The LiveView must not inspect `dashboard.player.last_synced_at` directly.
- For this slice, freshness is determined only by the existing `last_synced_at` freshness window.
- A dashboard with fewer rows than the requested limit is not stale solely because of row count. Fresh local rows remain sufficient.
- Keep the existing `get_dashboard/2` meaning as a local database read only.
- Keep the existing `get_or_sync_dashboard/2` meaning as local-first and sync-capable.
- Use `get_dashboard_refresh_state/2` as the local read plus freshness-classification boundary for UI search decisions.
- Keep LiveView assigns conceptually aligned to `form`, `dashboard`, `status`, and `error`.
- Use explicit user-visible statuses: empty, loading new profile, showing dashboard, showing stale dashboard while refreshing, and error. Existing atom names may be adjusted as long as the visible state semantics are clear.
- On each non-blank search, cancel any in-flight `:load_dashboard` task before deciding what to do next.
- When local dashboard data is fresh, render the dashboard immediately and do not start a refresh task.
- When local dashboard data is stale, render the cached dashboard immediately, show an updating indicator, and start an async refresh via `get_or_sync_dashboard/2`.
- When the local player or recent stats are missing, show the loading-new-profile state and start an async load via `get_or_sync_dashboard/2`.
- When a blocking load fails and no dashboard is available, set error state with no dashboard.
- When a background refresh fails and a dashboard is available, keep the dashboard visible and set a readable non-destructive error.
- Keep a single `error` assign for this slice. Interpret blocking versus non-blocking errors through status plus dashboard presence.
- Treat async cancellation exits as non-user-facing.
- Preserve existing chart hook behavior and data shape. Do not mix rendering approaches or redesign charts in this slice.
- Avoid splitting the dashboard into many new components. Keep the vertical slice focused on state behavior and async flow.
- Do not introduce new tables, auth, Oban, or the real FACEIT API as part of this work.

## Testing Decisions

- Good tests should assert external behavior: visible LiveView states, stable DOM IDs, public Analytics return values, and preserved dashboard visibility. Avoid tests that assert private helper names or implementation details.
- Add Analytics tests proving fresh local rows return `{:ok, :fresh, dashboard}`.
- Add Analytics tests proving stale local rows return `{:ok, :stale, dashboard}` when `last_synced_at` is older than the freshness window.
- Keep coverage for the existing rule that fresh local rows can satisfy a dashboard even when fewer rows exist than the requested limit.
- Add LiveView tests proving missing local data shows `#dashboard-loading` before `render_async/1` and then renders `#dashboard-summary`.
- Add LiveView tests proving stale cached data shows `#dashboard-refreshing` immediately while the old dashboard remains visible.
- Add LiveView tests proving stale cached data plus a failing refresh keeps `#dashboard-summary` visible and shows `#dashboard-error`.
- Keep LiveView tests anchored on key DOM IDs such as `#player-search-form`, `#dashboard-loading`, `#dashboard-refreshing`, `#dashboard-summary`, and `#dashboard-error`.
- Use a test-only failing FACEIT client where needed to exercise refresh failure behavior.
- Use existing Analytics tests and PlayerDashboardLive tests as prior art.
- Run the project precommit alias after implementation and fix any failures.

## Out of Scope

- Real FACEIT API integration.
- Oban or background job orchestration.
- Auth/accounts.
- New database tables.
- Expanding fake data volume to 30 matches.
- Weakness report work.
- Advanced chart redesign.
- Demo parsing.
- Leetify-style time-to-kill stats.
- Rewriting the dashboard UI into many components.
- Changing chart data contracts unless strictly necessary to preserve current behavior.
- Introducing additional HTTP clients.

## Further Notes

This PRD is a narrow vertical slice to prepare the dashboard for slow or unreliable external calls. The intended flow is local dashboard read, immediate cached display when possible, async sync/refresh, and safe success/error handling. The architectural boundary remains: LiveView calls `Analytics`; `Analytics` coordinates FACEIT client access, normalization, importing, and database reads.
