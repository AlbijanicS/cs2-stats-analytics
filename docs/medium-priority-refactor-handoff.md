# Medium Priority Refactor Handoff

This file captures the remaining medium-priority refactors from the code review.

Constraints:

- Keep each refactor small and separately verifiable.
- Do not combine unrelated items in one change.
- Do not move business logic into LiveView.
- Preserve the fake FACEIT client.
- Prefer local helpers/components before creating new modules.
- Run `mix precommit` after edits.

## Current Context

High-priority items already addressed:

- Normalizer now treats core match stats as required while preserving optional entry stats.
- LiveView now formats `dashboard.averages.avg_headshot_percent` instead of recalculating it from `recent_stats`.
- FACEIT client now uses `Req` instead of direct `Finch`.
- Unused supervised `Finch` child was removed.
- `Analytics.sync_player/2` now passes the configured client through the import path instead of re-fetching it per match.

## Remaining Medium Refactors

### 1. Extract LiveView Function Components

File:

- `lib/cs2_stats_analytics_web/live/player_dashboard_live.ex`

Problem:

- `render/1` is large and mixes page shell, sidebar, search panel, summary cards, chart panel, latest match card, and recent matches table.

Goal:

- Extract small private function components in the same LiveView module.

Suggested components:

- `sidebar/1`
- `search_panel/1`
- `player_summary/1`
- `average_stats/1`
- `trend_chart_panel/1`
- `latest_match_card/1`
- `recent_matches_table/1`

What not to change:

- Do not create a separate component module yet.
- Do not change markup semantics or CSS unless needed for extraction.
- Do not change event names, DOM IDs, or tests.

Verification:

- `mix test test/cs2_stats_analytics_web/live/player_dashboard_live_test.exs`
- `mix precommit`

### 2. Centralize LiveView Assign Transitions

File:

- `lib/cs2_stats_analytics_web/live/player_dashboard_live.ex`

Problem:

- Dashboard loading state is spread across repeated assign chains involving `:dashboard`, `:status`, `:error`, and `:loading_nickname`.

Goal:

- Add small helpers for state transitions.

Possible helpers:

- `assign_loaded_dashboard(socket, dashboard)`
- `assign_loading_dashboard(socket, nickname)`
- `assign_refreshing_dashboard(socket, dashboard, nickname)`
- `assign_dashboard_error(socket, reason)`

What not to change:

- Do not change async behavior.
- Do not change cancellation handling.
- Do not change the stale-cache behavior where a cached dashboard remains visible during refresh.

Verification:

- `mix test test/cs2_stats_analytics_web/live/player_dashboard_live_test.exs`
- `mix precommit`

### 3. Consolidate Dashboard Freshness Logic

File:

- `lib/cs2_stats_analytics/analytics.ex`

Problem:

- `get_or_sync_dashboard/2` and `get_dashboard_refresh_state/2` both classify whether a dashboard is fresh or stale.

Goal:

- Introduce one private helper such as `classify_dashboard/2` returning:

  ```elixir
  {:ok, :fresh, dashboard}
  {:ok, :stale, dashboard}
  {:error, reason}
  ```

What not to change:

- Keep public function return shapes unchanged.
- Keep sync behavior unchanged.
- Keep `fresh_dashboard?/2` semantics unchanged unless there is a dedicated follow-up.

Verification:

- `mix test test/cs2_stats_analytics/analytics_test.exs`
- `mix precommit`

### 4. Consolidate Chart Tab Metadata

File:

- `lib/cs2_stats_analytics_web/live/player_dashboard_live.ex`

Problem:

- Chart tab behavior is spread across duplicated event clauses, title helper, description helper, and template literals.

Goal:

- Use one `handle_event("select_chart", %{"chart" => chart}, socket)` with a private parser.
- Keep chart metadata in one private helper or map.

Possible shape:

```elixir
defp chart_from_param("performance"), do: {:ok, :performance}
defp chart_from_param("aim"), do: {:ok, :aim}
defp chart_from_param(_chart), do: :error
```

What not to change:

- Do not change chart DOM IDs.
- Do not change hook names.
- Do not change chart data JSON shape.

Verification:

- `mix test test/cs2_stats_analytics_web/live/player_dashboard_live_test.exs`
- `mix precommit`

### 5. Extract Dashboard Calculation/Shaping Later

File:

- `lib/cs2_stats_analytics/analytics.ex`

Problem:

- `calculate_averages/1`, `latest_match_summary/1`, and `build_trends/1` make `Analytics` responsible for both orchestration and dashboard data shaping.

Goal:

- Defer this until stats grow further.
- If needed, extract an internal module such as `Cs2StatsAnalytics.Analytics.DashboardBuilder`.

What not to change:

- Do not create this abstraction prematurely.
- Do not change the dashboard map shape returned to the LiveView.

Verification:

- `mix test test/cs2_stats_analytics/analytics_test.exs`
- `mix test test/cs2_stats_analytics_web/live/player_dashboard_live_test.exs`
- `mix precommit`

### 6. Reduce Duplicated Stat Field Lists

Files:

- `lib/cs2_stats_analytics/schemas/player_match_stat.ex`
- `lib/cs2_stats_analytics/player_match_importer.ex`
- Possibly `lib/cs2_stats_analytics/faceit/normalizer.ex`

Problem:

- Stat fields are repeated in schema field declarations, changeset casts, importer conflict replacement, normalizer parsing, Analytics averages, and LiveView display.

Goal:

- Start small by sharing field lists between schema changesets and importer conflict replacement.

Possible approach:

- Add module attributes or public helpers on `PlayerMatchStat`, for example:

  ```elixir
  @stat_fields [...]
  def stat_fields, do: @stat_fields
  ```

What not to change:

- Do not introduce a broad stats abstraction.
- Do not change migrations.
- Do not alter persisted field names.
- Do not move parsing rules out of the normalizer as part of this item.

Verification:

- `mix test test/cs2_stats_analytics/analytics_test.exs`
- `mix precommit`

### 7. Consolidate Map Display Metadata

File:

- `lib/cs2_stats_analytics_web/live/player_dashboard_live.ex`

Problem:

- `map_image_url/1` and `pretty_map_name/1` duplicate map-key knowledge.

Goal:

- Consolidate map UI metadata into one helper/map.

Possible shape:

```elixir
defp map_metadata("de_mirage"), do: %{name: "Mirage", image_url: ~p"/assets/images/mirage.png"}
defp map_metadata(map), do: %{name: map, image_url: nil}
```

What not to change:

- Keep this UI-side for now.
- Do not introduce a domain module for maps yet.
- Do not change image assets.

Verification:

- `mix test test/cs2_stats_analytics_web/live/player_dashboard_live_test.exs`
- `mix precommit`

## Suggested Order

1. Centralize dashboard freshness logic in `Analytics`.
2. Centralize LiveView assign transitions.
3. Consolidate chart tab metadata.
4. Consolidate map display metadata.
5. Extract LiveView function components.
6. Reduce duplicated stat field lists.
7. Revisit dashboard calculation extraction only after the stat surface grows.

