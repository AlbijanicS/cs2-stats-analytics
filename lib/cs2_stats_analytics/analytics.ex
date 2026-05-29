defmodule Cs2StatsAnalytics.Analytics do
  @moduledoc """
  Public analytics context for the CS2/FACEIT dashboard.

  This module coordinates the use-case flow: read dashboard data from the
  database when it is fresh enough, fetch fake/remote FACEIT-shaped data when
  local data is missing or stale, normalize it, persist it, and return a
  dashboard-friendly data structure.

  UI modules should call this context instead of reaching into FACEIT clients,
  normalizers, importers, or schemas directly.
  """

  import Ecto.Query

  alias Cs2StatsAnalytics.Faceit.Normalizer
  alias Cs2StatsAnalytics.PlayerMatchImporter
  alias Cs2StatsAnalytics.Repo
  alias Cs2StatsAnalytics.Schemas.{Match, Player, PlayerMatchStat}

  @fresh_for_seconds 60 * 60

  def get_or_sync_dashboard(nickname, limit \\ 30) do
    case classify_dashboard(nickname, limit) do
      {:ok, :fresh, dashboard} ->
        {:ok, dashboard}

      {:ok, :stale, _dashboard} ->
        sync_and_get_dashboard(nickname, limit)

      {:error, :player_not_found} ->
        sync_and_get_dashboard(nickname, limit)

      {:error, :no_recent_stats} ->
        sync_and_get_dashboard(nickname, limit)

      error ->
        error
    end
  end

  def sync_player(nickname, limit \\ 30) do
    client = faceit_client()

    with {:ok, api_player} <- client.get_player_by_nickname(nickname),
         {:ok, player_attrs} <- Normalizer.normalize_player(api_player),
         ranking_attrs =
           fetch_country_ranking_attrs(client, api_player, player_attrs.faceit_player_id),
         player_attrs =
           player_attrs
           |> Map.merge(ranking_attrs)
           |> Map.put(:last_synced_at, now()),
         {:ok, history} <- client.get_player_history(player_attrs.faceit_player_id, limit) do
      history
      |> Map.get("items", [])
      |> Enum.take(limit)
      |> import_matches(player_attrs, client)
    end
  end

  def get_dashboard(nickname, limit \\ 30) do
    with {:ok, player} <- fetch_player_by_nickname(nickname),
         {:ok, recent_stats} <- fetch_recent_stats(player, limit) do
      {:ok,
       %{
         player: player,
         recent_stats: recent_stats,
         averages: calculate_averages(recent_stats),
         latest_match_summary: latest_match_summary(recent_stats),
         trends: build_trends(recent_stats)
       }}
    end
  end

  def get_dashboard_refresh_state(nickname, limit \\ 30) do
    classify_dashboard(nickname, limit)
  end

  def get_match_scoreboard(faceit_match_id) do
    with {:ok, match} <- fetch_match_by_faceit_id(faceit_match_id),
         {:ok, scoreboard} <- build_match_scoreboard(match) do
      {:ok, scoreboard}
    end
  end

  defp sync_and_get_dashboard(nickname, limit) do
    with {:ok, _imports} <- sync_player(nickname, limit) do
      get_dashboard(nickname, limit)
    end
  end

  defp classify_dashboard(nickname, limit) do
    case get_dashboard(nickname, limit) do
      {:ok, dashboard} ->
        state = if fresh_dashboard?(dashboard, limit), do: :fresh, else: :stale
        {:ok, state, dashboard}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp import_matches(api_matches, player_attrs, client) do
    Enum.reduce_while(api_matches, {:ok, []}, fn api_match, {:ok, imported_matches} ->
      case import_match(api_match, player_attrs, client) do
        {:ok, result} ->
          {:cont, {:ok, [result | imported_matches]}}

        error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, imported_matches} -> {:ok, Enum.reverse(imported_matches)}
      error -> error
    end
  end

  defp import_match(api_history_match, player_attrs, client) do
    with {:ok, api_match_stats} <- client.get_match_stats(api_history_match["match_id"]),
         {:ok, match_attrs} <- Normalizer.normalize_match(api_history_match, api_match_stats),
         {:ok, stats_attrs} <-
           Normalizer.normalize_player_match_stat(
             api_history_match,
             api_match_stats,
             player_attrs.faceit_player_id
           ) do
      PlayerMatchImporter.import_player_match(%{
        player: player_attrs,
        match: match_attrs,
        stats: stats_attrs
      })
    end
  end

  defp fetch_player_by_nickname(nickname) do
    case Repo.get_by(Player, nickname: nickname) do
      nil -> {:error, :player_not_found}
      player -> {:ok, player}
    end
  end

  defp fetch_match_by_faceit_id(faceit_match_id) do
    case Repo.get_by(Match, faceit_match_id: faceit_match_id) do
      nil -> {:error, :match_not_found}
      match -> {:ok, match}
    end
  end

  defp fetch_recent_stats(player, limit) do
    stats =
      PlayerMatchStat
      |> where([stat], stat.player_id == ^player.id)
      |> join(:inner, [stat], match in assoc(stat, :match))
      |> order_by([_stat, match], desc: match.finished_at)
      |> limit(^limit)
      |> preload([_stat, match], match: match)
      |> Repo.all()

    case stats do
      [] -> {:error, :no_recent_stats}
      stats -> {:ok, stats}
    end
  end

  defp calculate_averages(stats) do
    matches_played = length(stats)
    wins = Enum.count(stats, & &1.won)

    %{
      matches_played: matches_played,
      avg_kills: average(stats, :kills),
      avg_deaths: average(stats, :deaths),
      avg_assists: average(stats, :assists),
      avg_adr: average(stats, :adr),
      avg_headshot_percent: average(stats, :headshot_percent),
      avg_kd_ratio: average(stats, :kd_ratio),
      avg_entry_success_percent: average_rate_percent(stats, :entry_success_rate),
      win_rate: percentage(wins, matches_played)
    }
  end

  defp average(stats, field) do
    values =
      stats
      |> Enum.map(&Map.get(&1, field))
      |> Enum.reject(&is_nil/1)

    case values do
      [] ->
        nil

      values ->
        values
        |> Enum.sum()
        |> Kernel./(length(values))
        |> Float.round(2)
    end
  end

  defp average_rate_percent(stats, field) do
    values =
      stats
      |> Enum.map(&Map.get(&1, field))
      |> Enum.reject(&is_nil/1)

    case values do
      [] ->
        nil

      values ->
        values
        |> Enum.sum()
        |> Kernel./(length(values))
        |> Kernel.*(100)
        |> Float.round(1)
    end
  end

  defp percentage(_amount, 0), do: 0.0

  defp percentage(amount, total) do
    amount
    |> Kernel./(total)
    |> Kernel.*(100)
    |> Float.round(1)
  end

  defp latest_match_summary([latest_stat | _rest]) do
    match = latest_stat.match

    %{
      map: match.map,
      finished_at: match.finished_at,
      score_faction1: match.score_faction1,
      score_faction2: match.score_faction2,
      won: latest_stat.won,
      kills: latest_stat.kills,
      deaths: latest_stat.deaths,
      assists: latest_stat.assists,
      adr: latest_stat.adr,
      kd_ratio: latest_stat.kd_ratio
    }
  end

  defp latest_match_summary([]), do: nil

  defp build_trends(stats) do
    stats
    |> Enum.reverse()
    |> Enum.with_index(1)
    |> Enum.map(fn {stat, index} ->
      %{
        label: "Match #{index}",
        map: stat.match.map,
        finished_at: stat.match.finished_at,
        kills: stat.kills,
        deaths: stat.deaths,
        assists: stat.assists,
        adr: stat.adr,
        kd_ratio: stat.kd_ratio,
        headshot_percent: stat.headshot_percent,
        won: stat.won
      }
    end)
  end

  defp build_match_scoreboard(%Match{raw_payload: raw_payload} = match)
       when is_map(raw_payload) do
    history = raw_payload["history"] || %{}
    stats = raw_payload["stats"] || %{}

    with {:ok, round} <- first_stats_round(stats),
         teams <- build_scoreboard_teams(match, history, round),
         true <- Enum.any?(teams, &(&1.players != [])) do
      {:ok,
       %{
         match: match,
         map: match.map || get_in(round, ["round_stats", "Map"]),
         pretty_map_name: pretty_map_name(match.map || get_in(round, ["round_stats", "Map"])),
         score: %{
           faction1: match.score_faction1 || get_in(history, ["results", "score", "faction1"]),
           faction2: match.score_faction2 || get_in(history, ["results", "score", "faction2"])
         },
         winner: match.winner || get_in(history, ["results", "winner"]),
         teams: teams
       }}
    else
      _error -> {:error, :scoreboard_not_available}
    end
  end

  defp build_match_scoreboard(_match), do: {:error, :scoreboard_not_available}

  defp build_scoreboard_teams(match, history, round) do
    teams_by_id =
      round
      |> Map.get("teams", [])
      |> Enum.filter(&is_map/1)
      |> Map.new(fn team -> {team["team_id"], team} end)

    ["faction1", "faction2"]
    |> Enum.map(fn faction ->
      history_team = get_in(history, ["teams", faction]) || %{}

      api_team =
        Map.get(teams_by_id, history_team["team_id"]) || Map.get(teams_by_id, faction, %{})

      %{
        faction: faction,
        name: history_team["nickname"] || team_name_from_stats(api_team) || faction,
        won: (match.winner || get_in(history, ["results", "winner"])) == faction,
        score: score_for_faction(match, history, faction),
        players: build_scoreboard_players(api_team)
      }
    end)
  end

  defp build_scoreboard_players(api_team) do
    api_team
    |> Map.get("players", [])
    |> Enum.filter(&is_map/1)
    |> Enum.map(fn player ->
      player_stats = player["player_stats"] || %{}

      %{
        nickname: player["nickname"] || "Unknown",
        player_id: player["player_id"],
        kills: parse_int(player_stats["Kills"]),
        deaths: parse_int(player_stats["Deaths"]),
        assists: parse_int(player_stats["Assists"]),
        adr: parse_float(player_stats["ADR"]),
        kd_ratio: parse_float(player_stats["K/D Ratio"]),
        headshot_percent: parse_float(player_stats["Headshots %"]),
        mvps: parse_int(player_stats["MVPs"])
      }
    end)
  end

  defp team_name_from_stats(%{"team_stats" => %{"Team" => team_name}}), do: team_name
  defp team_name_from_stats(_api_team), do: nil

  defp first_stats_round(%{"rounds" => [round | _rest]}) when is_map(round), do: {:ok, round}
  defp first_stats_round(_stats), do: {:error, :scoreboard_not_available}

  defp score_for_faction(%Match{score_faction1: score}, _history, "faction1")
       when not is_nil(score),
       do: score

  defp score_for_faction(%Match{score_faction2: score}, _history, "faction2")
       when not is_nil(score),
       do: score

  defp score_for_faction(_match, history, faction),
    do: get_in(history, ["results", "score", faction])

  defp pretty_map_name(nil), do: "Unknown map"

  defp pretty_map_name(map) do
    map
    |> String.replace_prefix("de_", "")
    |> String.replace("_", " ")
    |> String.split(" ", trim: true)
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp parse_int(nil), do: nil
  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, _rest} -> integer
      :error -> nil
    end
  end

  defp parse_int(_value), do: nil

  defp parse_float(nil), do: nil
  defp parse_float(value) when is_float(value), do: Float.round(value, 2)
  defp parse_float(value) when is_integer(value), do: value / 1

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _rest} -> Float.round(float, 2)
      :error -> nil
    end
  end

  defp parse_float(_value), do: nil

  defp fetch_country_ranking_attrs(client, api_player, faceit_player_id) do
    region = get_in(api_player, ["games", "cs2", "region"])
    country = api_player["country"]

    if ranking_lookup_possible?(client, region, country) do
      case client.get_player_ranking(faceit_player_id, region, country) do
        {:ok, api_ranking} ->
          case Normalizer.normalize_ranking(api_ranking, faceit_player_id) do
            {:ok, ranking_attrs} -> Map.take(ranking_attrs, [:country_rank])
            {:error, _reason} -> %{}
          end

        {:error, _reason} ->
          %{}
      end
    else
      %{}
    end
  end

  defp ranking_lookup_possible?(client, region, country) do
    function_exported?(client, :get_player_ranking, 3) and
      is_binary(region) and region != "" and
      is_binary(country) and country != ""
  end

  defp fresh_dashboard?(dashboard, limit) do
    fresh?(dashboard.player) and length(dashboard.recent_stats) >= limit
  end

  defp fresh?(%Player{last_synced_at: nil}), do: false

  defp fresh?(%Player{last_synced_at: last_synced_at}) do
    DateTime.diff(now(), last_synced_at, :second) <= @fresh_for_seconds
  end

  defp now do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
  end

  defp faceit_client do
    Application.fetch_env!(:cs2_stats_analytics, :faceit_client)
  end
end
