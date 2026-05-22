defmodule Cs2StatsAnalytics.Faceit.Normalizer do
  def normalize_player(api_player) do
    cs2_game = get_in(api_player, ["games", "cs2"]) || %{}

    %{
      faceit_player_id: api_player["player_id"],
      nickname: api_player["nickname"],
      avatar_url: api_player["avatar"],
      country: api_player["country"],
      skill_level: cs2_game["skill_level"],
      faceit_elo: cs2_game["faceit_elo"]
    }
  end

  def normalize_match(api_history_match, api_match_stats) do
    %{
      faceit_match_id: api_history_match["match_id"],
      game: api_history_match["game_id"],
      map: get_map(api_match_stats),
      finished_at: parse_datetime(api_history_match["finished_at"]),
      winner: get_in(api_history_match, ["results", "winner"]),
      score_faction1: get_in(api_history_match, ["results", "score", "faction1"]),
      score_faction2: get_in(api_history_match, ["results", "score", "faction2"]),
      raw_payload: %{
        "history" => api_history_match,
        "stats" => api_match_stats
      }
    }
  end

  def normalize_player_match_stat(api_history_match, api_match_stats, faceit_player_id) do
    {team_id, api_player} = find_player(api_match_stats, faceit_player_id)

    player_stats = api_player["player_stats"] || %{}

    %{
      team_id: team_id,
      nickname_at_match: api_player["nickname"],
      kills: parse_int(player_stats["Kills"]),
      deaths: parse_int(player_stats["Deaths"]),
      assists: parse_int(player_stats["Assists"]),
      adr: parse_float(player_stats["ADR"]),
      headshots: parse_int(player_stats["Headshots"]),
      headshot_percent: parse_float(player_stats["Headshots %"]),
      kd_ratio: parse_float(player_stats["K/D Ratio"]),
      kr_ratio: parse_float(player_stats["K/R Ratio"]),
      mvps: parse_int(player_stats["MVPs"]),
      triple_kills: parse_int(player_stats["Triple Kills"]),
      quadro_kills: parse_int(player_stats["Quadro Kills"]),
      penta_kills: parse_int(player_stats["Penta Kills"]),
      won: team_id == get_in(api_history_match, ["results", "winner"]),
      raw_stats: player_stats
    }
  end

  defp get_map(api_match_stats) do
    api_match_stats
    |> get_in(["rounds"])
    |> List.first()
    |> get_in(["round_stats", "Map"])
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) do
    {:ok, datetime, _offset} = DateTime.from_iso8601(datetime_string)
    datetime
  end

  defp find_player(api_match_stats, faceit_player_id) do
    api_match_stats
    |> get_in(["rounds"])
    |> List.first()
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
  end

  defp parse_int(nil), do: nil

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    {number, _rest} = Integer.parse(value)
    number
  end

  defp parse_float(nil), do: nil

  defp parse_float(value) when is_float(value), do: value

  defp parse_float(value) when is_integer(value), do: value * 1.0

  defp parse_float(value) when is_binary(value) do
    {number, _rest} = Float.parse(value)
    number
  end
end
