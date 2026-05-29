defmodule Cs2StatsAnalyticsWeb.MatchShowLiveTest do
  use Cs2StatsAnalyticsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Cs2StatsAnalytics.Analytics

  test "renders a minimal scoreboard from a stored match raw payload", %{conn: conn} do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 1)

    {:ok, view, html} = live(conn, ~p"/matches/match_001?nickname=stefan")

    assert html =~ "Mirage"
    assert html =~ "Team Alpha"
    assert html =~ "Team Bravo"
    assert html =~ "stefan"
    assert html =~ "22 / 17 / 5"
    assert has_element?(view, "#dashboard-nav a[href='/?nickname=stefan']", "Dashboard")
  end

  test "renders an error state when the match is missing", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/matches/missing_match")

    assert html =~ "Match unavailable"
    assert html =~ "No stored match was found"
  end
end
