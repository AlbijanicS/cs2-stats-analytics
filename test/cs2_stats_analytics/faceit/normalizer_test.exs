defmodule Cs2StatsAnalytics.Faceit.NormalizerTest do
  use ExUnit.Case, async: true

  alias Cs2StatsAnalytics.Faceit.Normalizer

  test "normalize_player/1 returns an error when required player data is missing" do
    assert Normalizer.normalize_player(%{"nickname" => "stefan"}) == {:error, :missing_player_id}

    assert Normalizer.normalize_player(%{"player_id" => "player-1"}) ==
             {:error, :missing_nickname}
  end

  test "normalize_match/2 returns an error when match rounds are missing" do
    history_match = %{
      "match_id" => "match-1",
      "game_id" => "cs2",
      "finished_at" => "2026-05-18T20:00:00Z"
    }

    assert Normalizer.normalize_match(history_match, %{"rounds" => []}) ==
             {:error, :match_rounds_not_found}
  end

  test "normalize_match/2 returns an error for invalid finished_at values" do
    history_match = %{
      "match_id" => "match-1",
      "game_id" => "cs2",
      "finished_at" => "not-a-datetime"
    }

    stats = %{"rounds" => [%{"round_stats" => %{"Map" => "de_mirage"}}]}

    assert Normalizer.normalize_match(history_match, stats) == {:error, :invalid_finished_at}
  end

  test "normalize_player_match_stat/3 returns an error when player stats are missing" do
    history_match = %{"results" => %{"winner" => "faction1"}}
    stats = %{"rounds" => [%{"teams" => [%{"team_id" => "faction1", "players" => []}]}]}

    assert Normalizer.normalize_player_match_stat(history_match, stats, "player-1") ==
             {:error, :player_stats_not_found}
  end

  test "normalize_player_match_stat/3 returns an error for invalid stat numbers" do
    history_match = %{"results" => %{"winner" => "faction1"}}

    stats = %{
      "rounds" => [
        %{
          "teams" => [
            %{
              "team_id" => "faction1",
              "players" => [
                %{
                  "player_id" => "player-1",
                  "nickname" => "stefan",
                  "player_stats" => %{"Kills" => "many"}
                }
              ]
            }
          ]
        }
      ]
    }

    assert Normalizer.normalize_player_match_stat(history_match, stats, "player-1") ==
             {:error, :invalid_integer}
  end
end
