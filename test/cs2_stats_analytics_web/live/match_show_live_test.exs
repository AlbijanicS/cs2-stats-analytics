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
    assert has_element?(view, "#dashboard-nav a[href='/dashboard?nickname=stefan']", "Dashboard")

    assert has_element?(
             view,
             "#match-scoreboard tbody td a[href='/dashboard?nickname=stefan']",
             "stefan"
           )

    assert has_element?(view, "#match-leaders")
    assert has_element?(view, "#match-leader-top_fragger", "Top Fragger")
    assert has_element?(view, "#match-leader-highest_adr", "Highest ADR")
    assert has_element?(view, "#match-leader-best_kd", "Best K/D")
    assert has_element?(view, "#match-leader-most_headshots", "Most Headshots")
    assert has_element?(view, "#match-leader-most_utility_damage", "Most Utility Damage")
    assert has_element?(view, "#match-leader-top_fragger", "stefan")
    assert has_element?(view, "#match-leader-top_fragger", "22 kills")
  end

  test "renders an error state when the match is missing", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/matches/missing_match")

    assert html =~ "Match unavailable"
    assert html =~ "No stored match was found"
  end
end
