# Issue Pack: LiveView Local-First Async Dashboard States

Source PRD: `docs/prds/liveview-async-dashboard-states.md`

These issues are local markdown handoff tickets for a future Codex session. They are intentionally written as independently grabbable vertical slices, with blockers called out by local issue number.

## 1. Fresh cached dashboard renders without async refresh

Type: AFK

Blocked by: None - can start immediately

User stories covered: 10, 11, 12, 21, 22, 23, 25

### What to build

Add the public Analytics refresh-state boundary for local dashboard reads. A fresh locally cached dashboard should be classified and returned immediately, without triggering FACEIT client calls, and the LiveView should use that public API rather than inspecting persistence fields directly.

The existing `get_dashboard/2` behavior remains a local database read. The existing `get_or_sync_dashboard/2` behavior remains local-first and sync-capable. The new refresh-state API owns freshness classification and returns:

```elixir
{:ok, :fresh, dashboard}
{:ok, :stale, dashboard}
{:error, :player_not_found}
{:error, :no_recent_stats}
{:error, reason}
```

Freshness is based only on the existing `last_synced_at` freshness window. A dashboard with fewer rows than the requested limit remains valid when still fresh.

### Acceptance criteria

- [ ] `Analytics.get_dashboard_refresh_state/2` is public and returns `{:ok, :fresh, dashboard}` for fresh local dashboard rows.
- [ ] Fresh local dashboard rows do not trigger FACEIT client calls, even when fewer rows exist than the requested limit.
- [ ] The LiveView renders fresh cached dashboard data immediately from the public Analytics API.
- [ ] The LiveView does not inspect `dashboard.player.last_synced_at` or any schema freshness field directly.
- [ ] Analytics tests cover fresh local rows and the fewer-than-limit freshness rule.

## 2. Missing profile search uses blocking async load states

Type: AFK

Blocked by: 1. Fresh cached dashboard renders without async refresh

User stories covered: 1, 2, 3, 4, 5, 6, 7, 8, 9, 24

### What to build

Make missing local profile searches use an explicit blocking async load flow. The page should start empty, blank searches should show a friendly validation error, and non-blank searches with no local dashboard should show a stable loading state while `get_or_sync_dashboard/2` runs asynchronously.

Successful first loads render the full dashboard summary, latest match, charts, and recent matches. Blocking failures, where no dashboard is available, render a friendly error and no dashboard.

### Acceptance criteria

- [ ] Initial page render has `#player-search-form` and no dashboard content.
- [ ] Blank nickname submit keeps the dashboard empty and shows `#dashboard-error` with a friendly validation message.
- [ ] Missing local data shows `#dashboard-loading` before async completion.
- [ ] Successful async completion renders `#dashboard-summary`, latest match, chart sections, and recent matches.
- [ ] Unknown player, missing history, missing stats, and no recent stats failures render friendly blocking errors.
- [ ] LiveView tests use key DOM IDs, including `#player-search-form`, `#dashboard-loading`, `#dashboard-summary`, and `#dashboard-error`.

## 3. Stale cached dashboard refreshes in the background

Type: AFK

Blocked by: 1. Fresh cached dashboard renders without async refresh

User stories covered: 13, 14, 15, 21, 22, 23, 24, 25

### What to build

When local dashboard data exists but is stale, render the cached dashboard immediately, show an updating indicator, and start an async refresh through `get_or_sync_dashboard/2`. On successful refresh, replace the stale dashboard with the refreshed dashboard.

The LiveView should keep assigns conceptually aligned around `form`, `dashboard`, `status`, and `error`, with explicit visible states for showing stale dashboard while refreshing.

### Acceptance criteria

- [ ] `Analytics.get_dashboard_refresh_state/2` returns `{:ok, :stale, dashboard}` for local dashboard rows older than the freshness window.
- [ ] Stale cached data renders `#dashboard-summary` immediately.
- [ ] Stale cached data shows a stable `#dashboard-refreshing` DOM target while refresh is in progress.
- [ ] Successful async refresh replaces the stale dashboard with refreshed dashboard data.
- [ ] LiveView tests prove stale cached data remains visible before async completion and updates after `render_async/1`.

## 4. Failed stale refresh preserves visible dashboard

Type: AFK

Blocked by: 3. Stale cached dashboard refreshes in the background

User stories covered: 16, 17, 24

### What to build

Handle failed background refreshes as non-destructive errors. If a dashboard is already visible and the refresh fails, keep the cached dashboard on screen and show a readable warning/error that explains the data may not be current.

Keep a single `error` assign for this slice. Interpret blocking versus non-blocking errors through status plus dashboard presence.

### Acceptance criteria

- [ ] A stale dashboard plus refresh failure keeps `#dashboard-summary` visible.
- [ ] The same failure shows `#dashboard-error` with a readable non-destructive message.
- [ ] Blocking load failures with no dashboard still show an error state with no dashboard.
- [ ] A test-only failing FACEIT client exercises the stale refresh failure path.
- [ ] LiveView tests assert visible outcomes rather than private helper names.

## 5. Repeated searches cancel in-flight dashboard tasks

Type: AFK

Blocked by:

- 2. Missing profile search uses blocking async load states
- 3. Stale cached dashboard refreshes in the background

User stories covered: 18, 19, 24

### What to build

On each non-blank search, cancel any in-flight `:load_dashboard` task before deciding how to handle the new search. Outdated async results should not waste work or overwrite newer user intent. Cancellation exits should stay non-user-facing.

### Acceptance criteria

- [ ] Non-blank searches cancel any existing `:load_dashboard` task before starting a new load or refresh.
- [ ] Cancellation exits do not render `#dashboard-error`.
- [ ] Older async results cannot overwrite the dashboard for a newer submitted nickname.
- [ ] LiveView tests cover repeated search behavior through user-visible state.

## 6. Chart hooks survive dashboard refresh replacement

Type: AFK

Blocked by: 3. Stale cached dashboard refreshes in the background

User stories covered: 20, 24

### What to build

Preserve the existing chart hook behavior and data shape after async dashboard refreshes. Do not redesign charts, split the dashboard into many components, or change chart rendering approaches unless strictly necessary to keep hooks working.

### Acceptance criteria

- [ ] `#performance-trend-chart` keeps `phx-hook="AdrTrendChart"`, `phx-update="ignore"`, and valid `data-points` after dashboard refresh.
- [ ] `#aim-trend-chart` keeps `phx-hook="HeadshotTrendChart"`, `phx-update="ignore"`, and valid `data-points` after dashboard refresh.
- [ ] Chart data contracts remain compatible with the existing JavaScript hooks.
- [ ] LiveView tests cover chart hook presence after async dashboard replacement.

## Implementation guardrails

- Do not introduce new tables, auth, Oban, or the real FACEIT API.
- Do not add another HTTP client. Use the existing `Req` dependency if HTTP work is needed.
- Do not call FACEIT clients, normalizers, importers, schemas, or repo queries directly from the LiveView.
- Do not inspect `last_synced_at` in the LiveView.
- Do not redesign the charts or split the dashboard into many new components as part of these slices.
- Keep tests focused on public Analytics return values and user-visible LiveView states.
- Run `mix precommit` after implementation and fix any failures.
