defmodule Cs2StatsAnalytics.Analytics do
  import Ecto.Query
  alias Cs2StatsAnalytics.Schemas.{Player, PlayerMatchStat}
  alias Cs2StatsAnalytics.Faceit.{FakeClient, Normalizer}
  alias Cs2StatsAnalytics.PlayerMatchImporter
  alias Cs2StatsAnalytics.Repo

  def sync_player(nickname, limit \\ 30) do
    with {:ok, api_player} <- FakeClient.get_player_by_nickname(nickname),
         player_attrs =
           api_player
           |> Normalizer.normalize_player()
           |> Map.put(:last_synced_at, now()),
         {:ok, history} <- FakeClient.get_player_history(player_attrs.faceit_player_id, limit) do
      history
      |> Map.get("items", [])
      |> Enum.take(limit)
      |> import_matches(player_attrs)
    end
  end

  defp import_matches(api_matches, player_attrs) do
    Enum.reduce_while(api_matches, {:ok, []}, fn api_match, {:ok, imported_matches} ->
      case import_match(api_match, player_attrs) do
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

  defp import_match(api_history_match, player_attrs) do
    with {:ok, api_match_stats} <- FakeClient.get_match_stats(api_history_match["match_id"]) do
      match_attrs = Normalizer.normalize_match(api_history_match, api_match_stats)

      stats_attrs =
        Normalizer.normalize_player_match_stat(
          api_history_match,
          api_match_stats,
          player_attrs.faceit_player_id
        )

      PlayerMatchImporter.import_player_match(%{
        player: player_attrs,
        match: match_attrs,
        stats: stats_attrs
      })
    end
  end

  def get_dashboard(nickname) do
    with {:ok, player} <- fetch_player_by_nickname(nickname),
         {:ok, recent_stats} <- fetch_recent_stats(player, 30) do
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

  defp fetch_player_by_nickname(nickname) do
    case Repo.get_by(Player, nickname: nickname) do
      nil -> {:error, :player_not_found}
      player -> {:ok, player}
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

  defp percentage(_amount, 0), do: 0.0

  defp percentage(amount, total) do
    amount
    |> Kernel./(total)
    |> Kernel.*(100)
    |> Float.round(1)
  end

  defp now do
    DateTime.utc_now()
    |> DateTime.truncate(:second)
  end
end
