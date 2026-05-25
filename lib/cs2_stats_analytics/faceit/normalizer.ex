defmodule Cs2StatsAnalytics.Faceit.Normalizer do
  @moduledoc """
  Converts FACEIT-shaped API maps into internal attributes.

  The normalizer is the boundary between external data and the app's database
  shape. Public functions return `{:ok, attrs}` or `{:error, reason}` so bad
  or incomplete API responses do not crash callers.
  """

  def normalize_player(api_player) do
    cs2_game = get_in(api_player, ["games", "cs2"]) || %{}

    with {:ok, player_id} <- required(api_player["player_id"], :missing_player_id),
         {:ok, nickname} <- required(api_player["nickname"], :missing_nickname) do
      {:ok,
       %{
         faceit_player_id: player_id,
         nickname: nickname,
         avatar_url: api_player["avatar"],
         country: api_player["country"],
         skill_level: cs2_game["skill_level"],
         faceit_elo: cs2_game["faceit_elo"]
       }}
    end
  end

  def normalize_match(api_history_match, api_match_stats) do
    with {:ok, match_id} <- required(api_history_match["match_id"], :missing_match_id),
         {:ok, game} <- required(api_history_match["game_id"], :missing_game_id),
         {:ok, map} <- get_map(api_match_stats),
         {:ok, finished_at} <- parse_datetime(api_history_match["finished_at"]) do
      {:ok,
       %{
         faceit_match_id: match_id,
         game: game,
         map: map,
         finished_at: finished_at,
         winner: get_in(api_history_match, ["results", "winner"]),
         score_faction1: get_in(api_history_match, ["results", "score", "faction1"]),
         score_faction2: get_in(api_history_match, ["results", "score", "faction2"]),
         raw_payload: %{
           "history" => api_history_match,
           "stats" => api_match_stats
         }
       }}
    end
  end

  def normalize_player_match_stat(api_history_match, api_match_stats, faceit_player_id) do
    with {:ok, {team_id, api_player}} <- find_player(api_match_stats, faceit_player_id),
         player_stats = api_player["player_stats"] || %{},
         {:ok, kills} <- parse_int(player_stats["Kills"]),
         {:ok, deaths} <- parse_int(player_stats["Deaths"]),
         {:ok, assists} <- parse_int(player_stats["Assists"]),
         {:ok, adr} <- parse_float(player_stats["ADR"]),
         {:ok, headshots} <- parse_int(player_stats["Headshots"]),
         {:ok, headshot_percent} <- parse_float(player_stats["Headshots %"]),
         {:ok, kd_ratio} <- parse_float(player_stats["K/D Ratio"]),
         {:ok, kr_ratio} <- parse_float(player_stats["K/R Ratio"]),
         {:ok, mvps} <- parse_int(player_stats["MVPs"]),
         {:ok, triple_kills} <- parse_int(player_stats["Triple Kills"]),
         {:ok, quadro_kills} <- parse_int(player_stats["Quadro Kills"]),
         {:ok, penta_kills} <- parse_int(player_stats["Penta Kills"]) do
      {:ok,
       %{
         team_id: team_id,
         nickname_at_match: api_player["nickname"],
         kills: kills,
         deaths: deaths,
         assists: assists,
         adr: adr,
         headshots: headshots,
         headshot_percent: headshot_percent,
         kd_ratio: kd_ratio,
         kr_ratio: kr_ratio,
         mvps: mvps,
         triple_kills: triple_kills,
         quadro_kills: quadro_kills,
         penta_kills: penta_kills,
         won: won?(team_id, api_history_match, player_stats),
         raw_stats: player_stats
       }}
    end
  end

  defp required(nil, reason), do: {:error, reason}
  defp required("", reason), do: {:error, reason}
  defp required(value, _reason), do: {:ok, value}

  defp get_map(api_match_stats) do
    with {:ok, round} <- first_round(api_match_stats) do
      {:ok, get_in(round, ["round_stats", "Map"])}
    end
  end

  defp parse_datetime(nil), do: {:ok, nil}

  defp parse_datetime(unix_seconds) when is_integer(unix_seconds) do
    {:ok, DateTime.from_unix!(unix_seconds)}
  end

  defp parse_datetime(datetime_string) when is_binary(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      {:error, _reason} -> {:error, :invalid_datetime}
    end
  end

  defp find_player(api_match_stats, faceit_player_id) do
    with {:ok, round} <- first_round(api_match_stats) do
      player_match =
        round
        |> Map.get("teams", [])
        |> Enum.find_value(fn team ->
          player =
            team
            |> Map.get("players", [])
            |> Enum.find(fn player -> player["player_id"] == faceit_player_id end)

          if player do
            {team["team_id"], player}
          end
        end)

      case player_match do
        nil -> {:error, :player_stats_not_found}
        player_match -> {:ok, player_match}
      end
    end
  end

  defp first_round(api_match_stats) do
    case get_in(api_match_stats, ["rounds"]) do
      [round | _rest] when is_map(round) -> {:ok, round}
      _rounds -> {:error, :match_rounds_not_found}
    end
  end

  defp parse_int(nil), do: {:ok, nil}

  defp parse_int(value) when is_integer(value), do: {:ok, value}

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> {:ok, number}
      {_number, _rest} -> {:error, :invalid_integer}
      :error -> {:error, :invalid_integer}
    end
  end

  defp parse_int(_value), do: {:error, :invalid_integer}

  defp parse_float(nil), do: {:ok, nil}

  defp parse_float(value) when is_float(value), do: {:ok, value}

  defp parse_float(value) when is_integer(value), do: {:ok, value * 1.0}

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> {:ok, number}
      {_number, _rest} -> {:error, :invalid_float}
      :error -> {:error, :invalid_float}
    end
  end

  defp parse_float(_value), do: {:error, :invalid_float}

  defp won?(_team_id, _api_history_match, %{"Result" => "1"}), do: true
  defp won?(_team_id, _api_history_match, %{"Result" => "0"}), do: false

  defp won?(team_id, api_history_match, _player_stats) do
    team_id == get_in(api_history_match, ["results", "winner"])
  end
end
