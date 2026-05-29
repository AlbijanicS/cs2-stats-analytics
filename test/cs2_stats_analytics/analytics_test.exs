defmodule Cs2StatsAnalytics.AnalyticsTest do
  use Cs2StatsAnalytics.DataCase, async: false

  alias Cs2StatsAnalytics.Analytics
  alias Cs2StatsAnalytics.Repo
  alias Cs2StatsAnalytics.Schemas.{Match, Player, PlayerMatchStat}

  defmodule ErrorClient do
    def get_player_by_nickname(_nickname), do: {:error, :unexpected_fetch}
    def get_player_history(_player_id, _limit), do: {:error, :unexpected_fetch}
    def get_match_stats(_match_id), do: {:error, :unexpected_fetch}
  end

  setup do
    original_client = Application.fetch_env!(:cs2_stats_analytics, :faceit_client)

    on_exit(fn ->
      Application.put_env(:cs2_stats_analytics, :faceit_client, original_client)
    end)
  end

  test "sync_player/2 imports player, matches, and stats idempotently" do
    assert {:ok, imported_matches} = Analytics.sync_player("stefan", 3)
    assert length(imported_matches) == 3

    assert Repo.aggregate(Player, :count) == 1
    assert Repo.aggregate(Match, :count) == 3
    assert Repo.aggregate(PlayerMatchStat, :count) == 3

    assert {:ok, imported_matches} = Analytics.sync_player("stefan", 3)
    assert length(imported_matches) == 3

    assert Repo.aggregate(Player, :count) == 1
    assert Repo.aggregate(Match, :count) == 3
    assert Repo.aggregate(PlayerMatchStat, :count) == 3
  end

  test "get_dashboard/1 returns dashboard data from imported database rows" do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 3)

    assert {:ok, dashboard} = Analytics.get_dashboard("stefan")

    assert dashboard.player.nickname == "stefan"
    assert dashboard.averages.matches_played == 3
    assert dashboard.averages.win_rate == 66.7
    assert dashboard.latest_match_summary.map == "de_ancient"
    assert length(dashboard.recent_stats) == 3
    assert length(dashboard.trends) == 3
  end

  test "get_or_sync_dashboard/2 uses fresh local dashboard rows before fetching" do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 3)

    Application.put_env(:cs2_stats_analytics, :faceit_client, ErrorClient)

    assert {:ok, dashboard} = Analytics.get_or_sync_dashboard("stefan", 3)
    assert dashboard.player.nickname == "stefan"
    assert dashboard.averages.matches_played == 3
  end

  test "get_or_sync_dashboard/2 syncs fresh local rows when fewer than the requested limit exist" do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 3)

    assert {:ok, dashboard} = Analytics.get_or_sync_dashboard("stefan", 10)
    assert dashboard.player.nickname == "stefan"
    assert dashboard.averages.matches_played == 10
  end

  test "get_or_sync_dashboard/2 returns imported rows after sync when fewer than the requested limit are available" do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 3)

    assert {:ok, dashboard} = Analytics.get_or_sync_dashboard("stefan", 20)
    assert dashboard.player.nickname == "stefan"
    assert dashboard.averages.matches_played == 10
  end

  test "get_dashboard_refresh_state/2 returns stale local rows when fewer than the requested limit exist" do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 3)

    Application.put_env(:cs2_stats_analytics, :faceit_client, ErrorClient)

    assert {:ok, :stale, dashboard} = Analytics.get_dashboard_refresh_state("stefan", 10)
    assert dashboard.player.nickname == "stefan"
    assert dashboard.averages.matches_played == 3
  end

  test "get_dashboard_refresh_state/2 returns stale local rows outside the freshness window" do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 3)
    player = Repo.get_by!(Player, nickname: "stefan")
    stale_at = DateTime.utc_now() |> DateTime.add(-61, :minute) |> DateTime.truncate(:second)

    player
    |> Player.changeset(%{last_synced_at: stale_at})
    |> Repo.update!()

    Application.put_env(:cs2_stats_analytics, :faceit_client, ErrorClient)

    assert {:ok, :stale, dashboard} = Analytics.get_dashboard_refresh_state("stefan", 10)
    assert dashboard.player.nickname == "stefan"
    assert dashboard.averages.matches_played == 3
  end

  test "get_or_sync_dashboard/2 fetches when the player is missing locally" do
    assert {:ok, dashboard} = Analytics.get_or_sync_dashboard("stefan", 3)

    assert dashboard.player.nickname == "stefan"
    assert Repo.aggregate(Player, :count) == 1
    assert Repo.aggregate(Match, :count) == 3
    assert Repo.aggregate(PlayerMatchStat, :count) == 3
  end

  test "get_dashboard/1 returns a tagged error when player is missing" do
    assert Analytics.get_dashboard("unknown") == {:error, :player_not_found}
  end

  test "get_match_scoreboard/1 builds a scoreboard from stored raw match payload" do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 1)

    assert {:ok, scoreboard} = Analytics.get_match_scoreboard("match_001")

    assert scoreboard.pretty_map_name == "Mirage"
    assert scoreboard.score == %{faction1: 13, faction2: 9}
    assert scoreboard.winner == "faction1"

    assert [team_alpha, team_bravo] = scoreboard.teams
    assert team_alpha.name == "Team Alpha"
    assert team_alpha.won
    assert team_alpha.score == 13

    assert [player] = team_alpha.players
    assert player.nickname == "stefan"
    assert player.kills == 22
    assert player.deaths == 17
    assert player.assists == 5
    assert player.adr == 84.5
    assert player.kd_ratio == 1.29
    assert player.headshots == 11
    assert player.utility_damage == nil
    assert player.headshot_percent == 50.0
    assert player.mvps == 3

    assert scoreboard.leaders.top_fragger == %{
             label: "Top Fragger",
             nickname: "stefan",
             value: 22,
             detail: "22 kills"
           }

    assert scoreboard.leaders.highest_adr == %{
             label: "Highest ADR",
             nickname: "stefan",
             value: 84.5,
             detail: "84.5 ADR"
           }

    assert scoreboard.leaders.best_kd == %{
             label: "Best K/D",
             nickname: "stefan",
             value: 1.29,
             detail: "1.29 K/D"
           }

    assert scoreboard.leaders.most_headshots == %{
             label: "Most Headshots",
             nickname: "stefan",
             value: 11,
             detail: "11 headshots"
           }

    assert scoreboard.leaders.most_utility_damage == %{
             label: "Most Utility Damage",
             nickname: nil,
             value: nil,
             detail: "No data"
           }

    assert team_bravo.name == "Team Bravo"
    refute team_bravo.won
    assert team_bravo.score == 9
    assert team_bravo.players == []
  end

  test "get_match_scoreboard/1 maps real FACEIT team ids back to factions" do
    assert {:ok, _match} =
             %Match{}
             |> Match.changeset(%{
               faceit_match_id: "real_team_ids_match",
               game: "cs2",
               map: "de_mirage",
               winner: "faction1",
               score_faction1: 13,
               score_faction2: 3,
               raw_payload: %{
                 "history" => %{
                   "teams" => %{
                     "faction1" => %{
                       "team_id" => "captain-a",
                       "nickname" => "team_alpha"
                     },
                     "faction2" => %{
                       "team_id" => "captain-b",
                       "nickname" => "team_beta"
                     }
                   },
                   "results" => %{
                     "winner" => "faction1",
                     "score" => %{"faction1" => 13, "faction2" => 3}
                   }
                 },
                 "stats" => %{
                   "rounds" => [
                     %{
                       "round_stats" => %{"Map" => "de_mirage"},
                       "teams" => [
                         %{
                           "team_id" => "captain-a",
                           "players" => [
                             %{
                               "player_id" => "player-a",
                               "nickname" => "alpha",
                               "player_stats" => %{
                                 "Kills" => "20",
                                 "Deaths" => "10",
                                 "Assists" => "5",
                                 "ADR" => "101.4",
                                 "K/D Ratio" => "2.00",
                                 "Headshots" => "9",
                                 "Headshots %" => "55",
                                 "Utility Damage" => "80",
                                 "MVPs" => "4"
                               }
                             }
                           ]
                         },
                         %{
                           "team_id" => "captain-b",
                           "players" => [
                             %{
                               "player_id" => "player-b",
                               "nickname" => "beta",
                               "player_stats" => %{
                                 "Kills" => "8",
                                 "Deaths" => "18",
                                 "Assists" => "3",
                                 "ADR" => "50.1",
                                 "K/D Ratio" => "0.44",
                                 "Headshots" => "11",
                                 "Headshots %" => "25",
                                 "Utility Damage" => "144",
                                 "MVPs" => "1"
                               }
                             }
                           ]
                         }
                       ]
                     }
                   ]
                 }
               }
             })
             |> Repo.insert()

    assert {:ok, scoreboard} = Analytics.get_match_scoreboard("real_team_ids_match")

    assert [team_alpha, team_beta] = scoreboard.teams
    assert team_alpha.name == "team_alpha"
    assert [%{nickname: "alpha", kills: 20}] = team_alpha.players
    assert team_beta.name == "team_beta"
    assert [%{nickname: "beta", deaths: 18}] = team_beta.players

    assert scoreboard.leaders.top_fragger.nickname == "alpha"
    assert scoreboard.leaders.top_fragger.value == 20
    assert scoreboard.leaders.highest_adr.nickname == "alpha"
    assert scoreboard.leaders.highest_adr.value == 101.4
    assert scoreboard.leaders.best_kd.nickname == "alpha"
    assert scoreboard.leaders.best_kd.value == 2.0
    assert scoreboard.leaders.most_headshots.nickname == "beta"
    assert scoreboard.leaders.most_headshots.value == 11
    assert scoreboard.leaders.most_utility_damage.nickname == "beta"
    assert scoreboard.leaders.most_utility_damage.value == 144
    assert scoreboard.leaders.most_utility_damage.detail == "144 utility damage"
  end

  test "get_match_scoreboard/1 returns match_not_found for an unknown match" do
    assert Analytics.get_match_scoreboard("missing_match") == {:error, :match_not_found}
  end

  test "get_match_scoreboard/1 returns scoreboard_not_available when raw payload is missing stats" do
    assert {:ok, match} =
             %Match{}
             |> Match.changeset(%{
               faceit_match_id: "match_without_stats",
               game: "cs2",
               map: "de_mirage",
               raw_payload: %{}
             })
             |> Repo.insert()

    assert match.faceit_match_id == "match_without_stats"

    assert Analytics.get_match_scoreboard("match_without_stats") ==
             {:error, :scoreboard_not_available}
  end
end
