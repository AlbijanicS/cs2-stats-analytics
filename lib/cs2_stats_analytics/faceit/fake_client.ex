defmodule Cs2StatsAnalytics.Faceit.FakeClient do
  def get_player_by_nickname("stefan") do
    {:ok,
     %{
       "player_id" => "faceit_player_123",
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

  def get_player_history("faceit_player_123", _limit) do
    {:ok,
     %{
       "items" => [
         %{
           "match_id" => "match_001",
           "game_id" => "cs2",
           "finished_at" => "2026-05-18T20:00:00Z",
           "teams" => %{
             "faction1" => %{"nickname" => "Team Alpha"},
             "faction2" => %{"nickname" => "Team Bravo"}
           },
           "results" => %{
             "winner" => "faction1",
             "score" => %{"faction1" => 13, "faction2" => 9}
           }
         },
         %{
           "match_id" => "match_002",
           "game_id" => "cs2",
           "finished_at" => "2026-05-19T21:30:00Z",
           "teams" => %{
             "faction1" => %{"nickname" => "Team Alpha"},
             "faction2" => %{"nickname" => "Team Delta"}
           },
           "results" => %{
             "winner" => "faction2",
             "score" => %{"faction1" => 10, "faction2" => 13}
           }
         },
         %{
           "match_id" => "match_003",
           "game_id" => "cs2",
           "finished_at" => "2026-05-20T19:15:00Z",
           "teams" => %{
             "faction1" => %{"nickname" => "Team Echo"},
             "faction2" => %{"nickname" => "Team Alpha"}
           },
           "results" => %{
             "winner" => "faction2",
             "score" => %{"faction1" => 11, "faction2" => 13}
           }
         }
       ]
     }}
  end

  def get_player_history(_player_id, _limit) do
    {:error, :player_history_not_found}
  end

  def get_match_stats("match_001") do
    {:ok,
     %{
       "match_id" => "match_001",
       "rounds" => [
         %{
           "round_stats" => %{
             "Map" => "de_mirage"
           },
           "teams" => [
             %{
               "team_id" => "faction1",
               "players" => [
                 %{
                   "player_id" => "faceit_player_123",
                   "nickname" => "stefan",
                   "player_stats" => %{
                     "Kills" => "22",
                     "Deaths" => "17",
                     "Assists" => "5",
                     "ADR" => "84.5",
                     "Headshots" => "11",
                     "Headshots %" => "50",
                     "K/D Ratio" => "1.29",
                     "K/R Ratio" => "0.85",
                     "MVPs" => "3",
                     "Triple Kills" => "1",
                     "Quadro Kills" => "0",
                     "Penta Kills" => "0"
                   }
                 }
               ]
             }
           ]
         }
       ]
     }}
  end

  def get_match_stats("match_002") do
    {:ok,
     %{
       "match_id" => "match_002",
       "rounds" => [
         %{
           "round_stats" => %{
             "Map" => "de_inferno"
           },
           "teams" => [
             %{
               "team_id" => "faction1",
               "players" => [
                 %{
                   "player_id" => "faceit_player_123",
                   "nickname" => "stefan",
                   "player_stats" => %{
                     "Kills" => "14",
                     "Deaths" => "20",
                     "Assists" => "4",
                     "ADR" => "61.2",
                     "Headshots" => "7",
                     "Headshots %" => "50",
                     "K/D Ratio" => "0.70",
                     "K/R Ratio" => "0.61",
                     "MVPs" => "1",
                     "Triple Kills" => "0",
                     "Quadro Kills" => "0",
                     "Penta Kills" => "0"
                   }
                 }
               ]
             }
           ]
         }
       ]
     }}
  end

  def get_match_stats("match_003") do
    {:ok,
     %{
       "match_id" => "match_003",
       "rounds" => [
         %{
           "round_stats" => %{
             "Map" => "de_ancient"
           },
           "teams" => [
             %{
               "team_id" => "faction2",
               "players" => [
                 %{
                   "player_id" => "faceit_player_123",
                   "nickname" => "stefan",
                   "player_stats" => %{
                     "Kills" => "26",
                     "Deaths" => "15",
                     "Assists" => "6",
                     "ADR" => "96.8",
                     "Headshots" => "13",
                     "Headshots %" => "50",
                     "K/D Ratio" => "1.73",
                     "K/R Ratio" => "1.00",
                     "MVPs" => "4",
                     "Triple Kills" => "2",
                     "Quadro Kills" => "1",
                     "Penta Kills" => "0"
                   }
                 }
               ]
             }
           ]
         }
       ]
     }}
  end

  def get_match_stats(_match_id) do
    {:error, :match_stats_not_found}
  end
end
