# CS2 FACEIT Stats Dashboard — Phoenix/LiveView Build Plan

## Project goal

Build a modern Phoenix LiveView analytics dashboard where a player enters a FACEIT nickname and sees recent CS2 performance stats.

The first real dashboard view should focus on:

- Average stats from the last 30 matches
- Trend graphs over those matches
- A summary of the most recent match
- A simple weakness report based on stats
- A clean architecture that can start with a fake client and later switch to the real FACEIT API

The goal is not to build a giant app. The goal is to practice web-app fundamentals in a realistic but controlled way:

- API client design
- Normalizing external responses
- Database schema design
- Ecto associations
- Ecto.Multi imports
- LiveView UI and loading states
- Basic analytics and charts
- ETC-friendly software design

---

## Core principle

Do not build the dashboard around the external API shape.

Build the dashboard around your own internal database shape.

External data should go through this pipeline:

```text
External API response / fake API response
  ↓
Normalizer
  ↓
Internal attrs
  ↓
Database
  ↓
Dashboard queries
  ↓
LiveView graphs and summaries
```

This keeps the app easier to change. If the FACEIT response shape changes later, the dashboard should not care. Only the client/normalizer should change.

---

## Main architecture

```text
Cs2StatsWeb.PlayerDashboardLive
  UI, profile search, loading states, graphs

Cs2Stats.CS2
  context; public API for the domain

Cs2Stats.CS2.FakeFaceitClient
  fake external client used first

Cs2Stats.CS2.FaceitClient
  real external client added later

Cs2Stats.CS2.FaceitNormalizer
  converts FACEIT-shaped responses into app-shaped attrs

Cs2Stats.CS2.Player
  FACEIT/CS2 player schema

Cs2Stats.CS2.Match
  CS2 match schema

Cs2Stats.CS2.PlayerMatchStat
  join schema with one player's stats in one match
```

The LiveView should not know about HTTP endpoints, API headers, FACEIT response nesting, or JSON parsing details.

---

## Database design

Use three main tables.

### players

Represents a FACEIT/CS2 player.

Fields:

```text
id
faceit_player_id
nickname
steam_id
avatar_url
country
skill_level
faceit_elo
last_synced_at
inserted_at
updated_at
```

Important index:

```elixir
create unique_index(:players, [:faceit_player_id])
```

### matches

Represents a CS2 match.

Fields:

```text
id
faceit_match_id
game
map
started_at
finished_at
winner
score_faction1
score_faction2
raw_payload
inserted_at
updated_at
```

Important index:

```elixir
create unique_index(:matches, [:faceit_match_id])
```

### player_match_stats

Represents one player's stats inside one match.

This is the join table between players and matches, but it also contains performance data.

Fields:

```text
id
player_id
match_id
team_id
nickname_at_match
kills
deaths
assists
adr
headshots
headshot_percent
kd_ratio
kr_ratio
mvps
triple_kills
quadro_kills
penta_kills
won
raw_stats
inserted_at
updated_at
```

Important index:

```elixir
create unique_index(:player_match_stats, [:player_id, :match_id])
```

Why this design?

```text
One player can play many matches.
One match can have many players.
One player has one stat line inside one match.
```

So stats belong on `player_match_stats`, not directly on `players` or `matches`.

---

## Build order

### Phase 1 — Create the Phoenix project and basic domain

Goal: establish the database shape before UI or API work.

Tasks:

1. Create Phoenix LiveView project.
2. Generate migrations for:
   - players
   - matches
   - player_match_stats
3. Add schemas and changesets.
4. Add associations:

```elixir
Player has_many :player_match_stats
Player has_many :matches, through: [:player_match_stats, :match]

Match has_many :player_match_stats
Match has_many :players, through: [:player_match_stats, :player]

PlayerMatchStat belongs_to :player
PlayerMatchStat belongs_to :match
```

Done when:

- Migrations run.
- Schemas compile.
- You can create basic records in IEx.

---

### Phase 2 — Build fake FACEIT client

Goal: practice API-client thinking without real API complexity.

Create:

```text
lib/cs2_stats/cs2/fake_faceit_client.ex
```

It should expose functions like:

```elixir
get_player_by_nickname("stefan")
get_player_history("fake_player_id", limit: 30)
get_match_stats("fake_match_id")
```

For now, only support one fake player:

```text
nickname: stefan
```

The fake client should return data that is intentionally API-shaped and a little ugly, for example string stats:

```elixir
%{
  "player_id" => "faceit_player_123",
  "nickname" => "stefan"
}
```

and:

```elixir
%{
  "match_id" => "match_001",
  "stats" => %{
    "Kills" => "22",
    "Deaths" => "17",
    "ADR" => "84.5",
    "Headshots %" => "48"
  }
}
```

Done when:

- You can call fake client functions from IEx.
- They return realistic maps.

---

### Phase 3 — Build the normalizer

Goal: isolate the external API shape.

Create:

```text
lib/cs2_stats/cs2/faceit_normalizer.ex
```

It should convert fake/FACEIT-shaped maps into clean internal attrs:

```elixir
%{
  faceit_player_id: "faceit_player_123",
  nickname: "stefan",
  faceit_elo: 1420,
  skill_level: 6
}
```

and:

```elixir
%{
  faceit_match_id: "match_001",
  map: "de_mirage",
  finished_at: ~U[2026-01-01 20:00:00Z]
}
```

and:

```elixir
%{
  kills: 22,
  deaths: 17,
  assists: 5,
  adr: 84.5,
  headshot_percent: 48.0,
  kd_ratio: 1.29,
  won: true
}
```

Done when:

- The normalizer can transform fake responses into clean attrs.
- The rest of the app never needs to read ugly API keys like `"Headshots %"`.

---

### Phase 4 — Build the import pipeline with Ecto.Multi

Goal: save player, match, and player-match stats safely.

Add a context function:

```elixir
CS2.import_player_match(%{
  player: player_attrs,
  match: match_attrs,
  stats: stats_attrs
})
```

Use `Ecto.Multi` because the data belongs together:

```text
insert/update player
insert/update match
insert/update player_match_stat
```

If one step fails, rollback the whole import.

Important rule:

```text
Do API calls before the transaction.
Only database writes should happen inside the transaction.
```

Done when:

- Running one context function imports fake player + fake matches.
- Re-running the import does not duplicate rows because of unique indexes/upserts.

---

### Phase 5 — Build dashboard queries

Goal: read from the database only.

Add context functions:

```elixir
CS2.get_player_by_nickname(nickname)
CS2.get_recent_stats(player, limit \\ 30)
CS2.get_dashboard(nickname)
```

Dashboard data should include:

```text
player info
last 30 match stat lines
averages
trend data for graphs
latest match summary
simple weakness report
```

Example calculated averages:

```text
avg_kills
avg_deaths
avg_assists
avg_adr
avg_headshot_percent
avg_kd_ratio
win_rate
```

Done when:

- You can call `CS2.get_dashboard("stefan")` from IEx and receive one clean dashboard map.

---

### Phase 6 — Build LiveView search and loading flow

Goal: modern dashboard flow.

User flow:

```text
User enters FACEIT nickname
  ↓
Check database first
  ↓
If data exists and is fresh, show immediately
  ↓
If missing/stale, fetch fake API data
  ↓
Save to database
  ↓
Reload dashboard
```

LiveView states:

```text
empty
loading/fetching
fresh dashboard
stale dashboard + refreshing
error
```

Start simple:

- Directly call context from LiveView.

Then improve:

- Use `start_async/3` so the UI can show “Fetching stats...” while the import runs.

Done when:

- Searching `stefan` imports data and displays dashboard.
- Searching unknown nickname shows a friendly error.

---

### Phase 7 — Add charts

Goal: practice analytics UI.

Start with these graphs:

```text
ADR over last 30 matches
K/D over last 30 matches
Headshot % over last 30 matches
Kills/deaths trend
```

Keep chart data prepared in the context or a dashboard builder module.

LiveView should receive graph-ready data like:

```elixir
[
  %{label: "Match 1", adr: 84.5, kd_ratio: 1.29},
  %{label: "Match 2", adr: 61.2, kd_ratio: 0.67}
]
```

Done when:

- Dashboard looks like a real analytics product.
- Graph data comes from database queries, not hardcoded values.

---

### Phase 8 — Add freshness/staleness logic

Goal: make the app feel like real stats websites.

Add:

```text
players.last_synced_at
```

Define freshness rule:

```text
fresh if synced within last 30 minutes
stale if older than 30 minutes
missing if player does not exist
```

Context function shape:

```elixir
CS2.get_or_sync_dashboard(nickname)
```

Possible returns:

```elixir
{:ok, :fresh, dashboard}
{:ok, :stale, dashboard}
{:sync_required, nickname}
{:error, reason}
```

Done when:

- Existing fresh data shows immediately.
- Existing stale data can show immediately while a refresh happens.
- New profiles show fetching state.

---

### Phase 9 — Replace fake client with real FACEIT client

Goal: swap data source without rewriting dashboard.

Create:

```text
lib/cs2_stats/cs2/faceit_client.ex
```

It should expose the same style of functions as the fake client:

```elixir
get_player_by_nickname(nickname)
get_player_history(player_id, opts)
get_match_stats(match_id)
```

The context should be able to call a configured client:

```elixir
config :cs2_stats, :faceit_client, Cs2Stats.CS2.FakeFaceitClient
```

Later:

```elixir
config :cs2_stats, :faceit_client, Cs2Stats.CS2.FaceitClient
```

Done when:

- Switching from fake to real client is a config/module change, not a rewrite.

---

## Pragmatic Programmer principles applied

### ETC — Easier To Change

Ask at each decision:

```text
Will this make the next change easier or harder?
```

Applied here:

- LiveView reads dashboard data, not raw API responses.
- FACEIT API details are isolated in a client.
- API response conversion is isolated in a normalizer.
- Dashboard queries read from database.
- Fake client can be replaced with real client later.

### DRY — Do not duplicate knowledge

Do not duplicate the same stat parsing logic in multiple places.

Bad:

```text
LiveView parses Kills
Context parses Kills
Graph module parses Kills
```

Good:

```text
FaceitNormalizer parses Kills once.
Everything else uses clean internal fields.
```

### Orthogonality

Changing one part should not force unrelated changes.

Examples:

```text
Changing chart design should not change API client code.
Changing FACEIT response parsing should not change LiveView code.
Changing database queries should not change HTTP request code.
```

### Tracer bullets

Build a small working vertical slice early:

```text
Fake client
  ↓
Normalizer
  ↓
Database import
  ↓
Dashboard query
  ↓
LiveView display
```

It does not need every stat or a perfect UI at first. It just needs to prove the architecture works end-to-end.

### Reversibility

Avoid decisions that are painful to reverse.

Examples:

- Use fake client first so real API details can change later.
- Store raw payloads while still learning the API.
- Keep client behind a small interface.
- Avoid Oban until background reliability is actually needed.

---

## What not to build at first

Do not start with:

```text
Oban
AI coach
demo file parsing
full auth/accounts
all 10 players in a match
complex role analysis
real-time multi-user features
```

These are good later, but they will distract from the main learning goal.

---

## Recommended first vertical slice

Build this first:

```text
Search "stefan"
  ↓
FakeFaceitClient returns fake player + last 3 matches
  ↓
Normalizer converts response
  ↓
Ecto.Multi saves player, matches, and player_match_stats
  ↓
CS2.get_dashboard("stefan") calculates averages
  ↓
LiveView shows player card, averages, and recent matches
```

Only after that works, increase from 3 fake matches to 30 fake matches and add graphs.

---

## Final architecture rule

The dashboard should always read from your database.

The API client should only be responsible for fetching external data.

The normalizer should only be responsible for converting external data into internal attrs.

The context should coordinate the flow.

The LiveView should display the result.

That is the clean, ETC-friendly approach.
