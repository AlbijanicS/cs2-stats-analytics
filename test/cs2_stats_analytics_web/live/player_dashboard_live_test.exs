defmodule Cs2StatsAnalyticsWeb.PlayerDashboardLiveTest do
  use Cs2StatsAnalyticsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Cs2StatsAnalytics.Analytics
  alias Cs2StatsAnalytics.Repo
  alias Cs2StatsAnalytics.Schemas.Player

  defmodule ErrorClient do
    def get_player_by_nickname(_nickname), do: {:error, :unexpected_fetch}
    def get_player_history(_player_id, _limit), do: {:error, :unexpected_fetch}
    def get_match_stats(_match_id), do: {:error, :unexpected_fetch}
  end

  defmodule FailingRefreshClient do
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

    def get_player_by_nickname(_nickname), do: {:error, :player_not_found}

    def get_player_history(_player_id, _limit) do
      {:ok,
       %{
         "items" => [
           %{
             "match_id" => "match_refresh_failure",
             "game_id" => "cs2",
             "finished_at" => "2026-05-28T20:35:00Z",
             "teams" => %{
               "faction1" => %{"nickname" => "Team Alpha"},
               "faction2" => %{"nickname" => "Team Bravo"}
             },
             "results" => %{
               "winner" => "faction1",
               "score" => %{"faction1" => 13, "faction2" => 10}
             }
           }
         ]
       }}
    end

    def get_match_stats(_match_id) do
      test_pid = Application.fetch_env!(:cs2_stats_analytics, :live_view_test_pid)
      send(test_pid, {:refresh_requested, self()})

      receive do
        :fail_refresh -> {:error, :match_stats_not_found}
      end
    end
  end

  defmodule BlockingUnknownClient do
    def get_player_by_nickname("unknown") do
      test_pid = Application.fetch_env!(:cs2_stats_analytics, :live_view_test_pid)
      send(test_pid, {:unknown_lookup_started, self()})

      receive do
        :finish_unknown_lookup -> {:error, :player_not_found}
      end
    end

    def get_player_by_nickname(_nickname), do: {:error, :unexpected_fetch}
    def get_player_history(_player_id, _limit), do: {:error, :unexpected_fetch}
    def get_match_stats(_match_id), do: {:error, :unexpected_fetch}
  end

  setup do
    original_client = Application.fetch_env!(:cs2_stats_analytics, :faceit_client)

    on_exit(fn ->
      Application.put_env(:cs2_stats_analytics, :faceit_client, original_client)
      Application.delete_env(:cs2_stats_analytics, :live_view_test_pid)
    end)
  end

  test "renders fresh cached dashboard immediately without async refresh", %{conn: conn} do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 10)
    Application.put_env(:cs2_stats_analytics, :faceit_client, ErrorClient)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#player-search-form", search: %{nickname: "stefan"})
    |> render_submit()

    assert_patch(view, ~p"/?nickname=stefan")
    assert has_element?(view, "#dashboard-summary")
    refute has_element?(view, "#dashboard-loading")
  end

  test "loads dashboard from nickname query param", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/?nickname=stefan")

    render_async(view)

    assert has_element?(view, "#dashboard-summary")
    assert has_element?(view, "#dashboard-summary", "stefan")
  end

  test "renders stale cached dashboard while refreshing and replaces it after async completion",
       %{
         conn: conn
       } do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 3)
    mark_player_stale!("stefan")

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#player-search-form", search: %{nickname: "stefan"})
    |> render_submit()

    assert has_element?(view, "#dashboard-summary", "3")
    assert has_element?(view, "#dashboard-refreshing", "Refreshing...")
    refute has_element?(view, "#dashboard-refreshing", "Updating cached stats")

    render_async(view)

    assert has_element?(view, "#dashboard-summary", "10")
    refute has_element?(view, "#dashboard-refreshing")

    assert has_element?(
             view,
             "#performance-trend-chart[phx-hook='AdrTrendChart'][phx-update='ignore'][data-points]"
           )

    refute has_element?(view, "#aim-trend-chart-section")
    refute has_element?(view, "#aim-trend-chart")
  end

  test "keeps incomplete dashboard visible when background refresh fails", %{conn: conn} do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 3)
    Application.put_env(:cs2_stats_analytics, :live_view_test_pid, self())
    Application.put_env(:cs2_stats_analytics, :faceit_client, FailingRefreshClient)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#player-search-form", search: %{nickname: "stefan"})
    |> render_submit()

    assert has_element?(view, "#dashboard-summary")
    assert has_element?(view, "#dashboard-refreshing")
    assert_receive {:refresh_requested, refresh_pid}
    send(refresh_pid, :fail_refresh)

    render_async(view)

    assert has_element?(view, "#dashboard-summary")
    refute has_element?(view, "#dashboard-error")
    refute has_element?(view, "#dashboard-refreshing")
  end

  test "repeated search cancels in-flight dashboard load without showing a cancellation error", %{
    conn: conn
  } do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 10)
    Application.put_env(:cs2_stats_analytics, :live_view_test_pid, self())
    Application.put_env(:cs2_stats_analytics, :faceit_client, BlockingUnknownClient)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#player-search-form", search: %{nickname: "unknown"})
    |> render_submit()

    assert has_element?(view, "#dashboard-loading")
    assert_receive {:unknown_lookup_started, _lookup_pid}

    view
    |> form("#player-search-form", search: %{nickname: "stefan"})
    |> render_submit()

    assert has_element?(view, "#dashboard-summary", "stefan")
    refute has_element?(view, "#dashboard-loading")
  end

  test "renders the dashboard after searching for a known fake player", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#player-search-form")
    refute has_element?(view, "#dashboard-summary")

    view
    |> form("#player-search-form", search: %{nickname: "stefan"})
    |> render_submit()

    render_async(view)

    assert has_element?(view, "#dashboard-summary")
    assert has_element?(view, "#dashboard-summary", "stefan")
    assert has_element?(view, "#dashboard-nav a[href='/matches?nickname=stefan']", "Matches")
    refute has_element?(view, "#recent-matches")

    assert has_element?(view, "#latest-match-summary", "Mirage")

    assert has_element?(
             view,
             "#latest-match-summary a[href='/matches/match_010?nickname=stefan']",
             "Mirage"
           )

    refute has_element?(view, "#latest-match-summary", "de_mirage")
    assert has_element?(view, "#latest-match-summary [style*='mirage.png']")

    assert has_element?(
             view,
             "#performance-trend-chart[phx-hook='AdrTrendChart'][phx-update='ignore'][data-points]"
           )

    refute has_element?(view, "#aim-trend-chart-section")
    refute has_element?(view, "#aim-trend-chart")

    view
    |> element("#aim-chart-tab")
    |> render_click()

    assert has_element?(
             view,
             "#aim-trend-chart[phx-hook='HeadshotTrendChart'][phx-update='ignore'][data-points]"
           )

    assert chart_count(view, "#aim-trend-chart") == 1
    assert has_element?(view, "#performance-trend-chart-section", "Aim Trend")
    refute has_element?(view, "#performance-trend-chart")

    view
    |> element("#performance-chart-tab")
    |> render_click()

    assert has_element?(
             view,
             "#performance-trend-chart[phx-hook='AdrTrendChart'][phx-update='ignore'][data-points]"
           )

    refute has_element?(view, "#aim-trend-chart")
  end

  test "keeps selected chart after searching again", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#player-search-form", search: %{nickname: "stefan"})
    |> render_submit()

    render_async(view)

    view
    |> element("#aim-chart-tab")
    |> render_click()

    assert has_element?(view, "#aim-trend-chart")

    view
    |> form("#player-search-form", search: %{nickname: "stefan"})
    |> render_submit()

    assert has_element?(
             view,
             "#aim-trend-chart[phx-hook='HeadshotTrendChart'][phx-update='ignore'][data-points]"
           )

    refute has_element?(view, "#performance-trend-chart")
  end

  test "renders an error for blank search", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#player-search-form", search: %{nickname: "   "})
    |> render_submit()

    assert has_element?(view, "#dashboard-error", "Enter a FACEIT nickname.")
  end

  defp mark_player_stale!(nickname) do
    stale_at = DateTime.utc_now() |> DateTime.add(-61, :minute) |> DateTime.truncate(:second)

    Player
    |> Repo.get_by!(nickname: nickname)
    |> Player.changeset(%{last_synced_at: stale_at})
    |> Repo.update!()
  end

  defp chart_count(view, selector) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> Enum.count()
  end
end
