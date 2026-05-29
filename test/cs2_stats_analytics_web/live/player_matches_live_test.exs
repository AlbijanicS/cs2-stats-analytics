defmodule Cs2StatsAnalyticsWeb.PlayerMatchesLiveTest do
  use Cs2StatsAnalyticsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Cs2StatsAnalytics.Analytics

  test "renders player match history and clickable recent matches", %{conn: conn} do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 10)

    {:ok, view, _html} = live(conn, ~p"/matches?nickname=stefan")

    assert has_element?(view, "#dashboard-nav a[href='/?nickname=stefan']", "Dashboard")
    assert has_element?(view, "h1", "stefan's Match History")
    refute has_element?(view, "#matches-player-card")
    assert has_element?(view, "#recent-matches", "Last 10")

    assert has_element?(
             view,
             "#recent-matches a[href='/matches/match_010?nickname=stefan']",
             "Mirage"
           )
  end

  test "renders an empty state without a nickname", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/matches")

    assert has_element?(view, "#matches-empty")
    refute has_element?(view, "#matches-player-card")
    refute has_element?(view, "#recent-matches")
  end
end
