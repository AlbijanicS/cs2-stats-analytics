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
    stale_at = DateTime.utc_now() |> DateTime.add(-16, :minute) |> DateTime.truncate(:second)

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
end
