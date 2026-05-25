defmodule Cs2StatsAnalytics.Faceit.FakeClient do
  @moduledoc """
  Fake FACEIT client used for local development and tests.

  The returned maps intentionally mimic the external FACEIT response shape so
  the rest of the application exercises the same normalization and persistence
  path that a real client will use later. This module should not know about
  database schemas or dashboard calculations.
  """

  @fake_player_id "faceit_player_123"

  @fake_matches [
    %{
      match_id: "match_001",
      map: "de_mirage",
      finished_at: "2026-05-18T20:00:00Z",
      team_id: "faction1",
      winner: "faction1",
      score_faction1: 13,
      score_faction2: 9,
      kills: "22",
      deaths: "17",
      assists: "5",
      adr: "84.5",
      headshots: "11",
      headshot_percent: "50",
      kd_ratio: "1.29",
      kr_ratio: "0.85",
      mvps: "3",
      triple_kills: "1",
      quadro_kills: "0",
      penta_kills: "0"
    },
    %{
      match_id: "match_002",
      map: "de_inferno",
      finished_at: "2026-05-19T21:30:00Z",
      team_id: "faction1",
      winner: "faction2",
      score_faction1: 10,
      score_faction2: 13,
      kills: "14",
      deaths: "20",
      assists: "4",
      adr: "61.2",
      headshots: "7",
      headshot_percent: "50",
      kd_ratio: "0.70",
      kr_ratio: "0.61",
      mvps: "1",
      triple_kills: "0",
      quadro_kills: "0",
      penta_kills: "0"
    },
    %{
      match_id: "match_003",
      map: "de_ancient",
      finished_at: "2026-05-20T19:15:00Z",
      team_id: "faction2",
      winner: "faction2",
      score_faction1: 11,
      score_faction2: 13,
      kills: "26",
      deaths: "15",
      assists: "6",
      adr: "96.8",
      headshots: "13",
      headshot_percent: "50",
      kd_ratio: "1.73",
      kr_ratio: "1.00",
      mvps: "4",
      triple_kills: "2",
      quadro_kills: "1",
      penta_kills: "0"
    },
    %{
      match_id: "match_004",
      map: "de_nuke",
      finished_at: "2026-05-21T18:40:00Z",
      team_id: "faction2",
      winner: "faction1",
      score_faction1: 13,
      score_faction2: 8,
      kills: "16",
      deaths: "19",
      assists: "7",
      adr: "69.4",
      headshots: "8",
      headshot_percent: "50",
      kd_ratio: "0.84",
      kr_ratio: "0.67",
      mvps: "1",
      triple_kills: "0",
      quadro_kills: "0",
      penta_kills: "0"
    },
    %{
      match_id: "match_005",
      map: "de_vertigo",
      finished_at: "2026-05-22T20:10:00Z",
      team_id: "faction1",
      winner: "faction1",
      score_faction1: 13,
      score_faction2: 6,
      kills: "24",
      deaths: "13",
      assists: "3",
      adr: "102.1",
      headshots: "15",
      headshot_percent: "62",
      kd_ratio: "1.85",
      kr_ratio: "1.09",
      mvps: "5",
      triple_kills: "1",
      quadro_kills: "1",
      penta_kills: "0"
    },
    %{
      match_id: "match_006",
      map: "de_overpass",
      finished_at: "2026-05-23T22:05:00Z",
      team_id: "faction1",
      winner: "faction2",
      score_faction1: 7,
      score_faction2: 13,
      kills: "12",
      deaths: "18",
      assists: "6",
      adr: "58.9",
      headshots: "5",
      headshot_percent: "42",
      kd_ratio: "0.67",
      kr_ratio: "0.55",
      mvps: "0",
      triple_kills: "0",
      quadro_kills: "0",
      penta_kills: "0"
    },
    %{
      match_id: "match_007",
      map: "de_anubis",
      finished_at: "2026-05-24T19:45:00Z",
      team_id: "faction2",
      winner: "faction2",
      score_faction1: 9,
      score_faction2: 13,
      kills: "21",
      deaths: "16",
      assists: "8",
      adr: "88.7",
      headshots: "10",
      headshot_percent: "48",
      kd_ratio: "1.31",
      kr_ratio: "0.91",
      mvps: "3",
      triple_kills: "1",
      quadro_kills: "0",
      penta_kills: "0"
    },
    %{
      match_id: "match_008",
      map: "de_dust2",
      finished_at: "2026-05-25T17:20:00Z",
      team_id: "faction1",
      winner: "faction1",
      score_faction1: 13,
      score_faction2: 11,
      kills: "19",
      deaths: "18",
      assists: "5",
      adr: "77.3",
      headshots: "9",
      headshot_percent: "47",
      kd_ratio: "1.06",
      kr_ratio: "0.76",
      mvps: "2",
      triple_kills: "0",
      quadro_kills: "0",
      penta_kills: "0"
    },
    %{
      match_id: "match_009",
      map: "de_train",
      finished_at: "2026-05-26T21:00:00Z",
      team_id: "faction2",
      winner: "faction1",
      score_faction1: 13,
      score_faction2: 4,
      kills: "9",
      deaths: "17",
      assists: "2",
      adr: "44.8",
      headshots: "4",
      headshot_percent: "44",
      kd_ratio: "0.53",
      kr_ratio: "0.43",
      mvps: "0",
      triple_kills: "0",
      quadro_kills: "0",
      penta_kills: "0"
    },
    %{
      match_id: "match_010",
      map: "de_mirage",
      finished_at: "2026-05-27T20:35:00Z",
      team_id: "faction1",
      winner: "faction1",
      score_faction1: 13,
      score_faction2: 10,
      kills: "28",
      deaths: "16",
      assists: "4",
      adr: "110.6",
      headshots: "16",
      headshot_percent: "57",
      kd_ratio: "1.75",
      kr_ratio: "1.12",
      mvps: "6",
      triple_kills: "2",
      quadro_kills: "1",
      penta_kills: "0"
    }
  ]

  def get_player_by_nickname("stefan") do
    {:ok,
     %{
       "player_id" => @fake_player_id,
       "nickname" => "stefan",
       "avatar" => "https://example.com/stefan.png",
       "country" => "RS",
       "games" => %{
         "cs2" => %{
           "skill_level" => 6,
           "faceit_elo" => 1420
         }
       }
     }}
  end

  def get_player_by_nickname(_nickname) do
    {:error, :player_not_found}
  end

  def get_player_history(_player_id, _limit \\ 30)

  def get_player_history(@fake_player_id, limit) do
    items =
      @fake_matches
      |> Enum.take(limit)
      |> Enum.map(&history_item/1)

    {:ok, %{"items" => items}}
  end

  def get_player_history(_player_id, _limit) do
    {:error, :player_history_not_found}
  end

  def get_match_stats(match_id) do
    case Enum.find(@fake_matches, &(&1.match_id == match_id)) do
      nil -> {:error, :match_stats_not_found}
      fake_match -> {:ok, match_stats_response(fake_match)}
    end
  end

  defp history_item(fake_match) do
    %{
      "match_id" => fake_match.match_id,
      "game_id" => "cs2",
      "finished_at" => fake_match.finished_at,
      "teams" => %{
        "faction1" => %{"nickname" => "Team Alpha"},
        "faction2" => %{"nickname" => "Team Bravo"}
      },
      "results" => %{
        "winner" => fake_match.winner,
        "score" => %{
          "faction1" => fake_match.score_faction1,
          "faction2" => fake_match.score_faction2
        }
      }
    }
  end

  defp match_stats_response(fake_match) do
    %{
      "match_id" => fake_match.match_id,
      "rounds" => [
        %{
          "round_stats" => %{
            "Map" => fake_match.map
          },
          "teams" => [
            %{
              "team_id" => fake_match.team_id,
              "players" => [
                %{
                  "player_id" => @fake_player_id,
                  "nickname" => "stefan",
                  "player_stats" => %{
                    "Kills" => fake_match.kills,
                    "Deaths" => fake_match.deaths,
                    "Assists" => fake_match.assists,
                    "ADR" => fake_match.adr,
                    "Headshots" => fake_match.headshots,
                    "Headshots %" => fake_match.headshot_percent,
                    "K/D Ratio" => fake_match.kd_ratio,
                    "K/R Ratio" => fake_match.kr_ratio,
                    "MVPs" => fake_match.mvps,
                    "Triple Kills" => fake_match.triple_kills,
                    "Quadro Kills" => fake_match.quadro_kills,
                    "Penta Kills" => fake_match.penta_kills
                  }
                }
              ]
            }
          ]
        }
      ]
    }
  end
end
