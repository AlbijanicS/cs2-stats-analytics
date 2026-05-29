defmodule Cs2StatsAnalyticsWeb.PlayerMatchesLiveTest do
  use Cs2StatsAnalyticsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Cs2StatsAnalytics.Analytics
  alias Cs2StatsAnalytics.Repo
  alias Cs2StatsAnalytics.Schemas.Match

  test "renders player match history and clickable recent matches", %{conn: conn} do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 10)

    {:ok, view, _html} = live(conn, ~p"/matches?nickname=stefan")

    assert has_element?(view, "#dashboard-nav a[href='/dashboard?nickname=stefan']", "Dashboard")
    assert has_element?(view, "h1", "stefan's Match History")
    refute has_element?(view, "#matches-player-card")
    assert has_element?(view, "#recent-matches", "Last 10")

    assert has_element?(
             view,
             "#recent-matches a[href='/matches/match_010?nickname=stefan']",
             "Mirage"
           )
  end

  test "renders FACEIT match ids that look like UUID route segments", %{conn: conn} do
    assert {:ok, _imported_matches} = Analytics.sync_player("stefan", 10)

    update_match_id!("match_010", "1-66a72de6-070d-4308-966f-eea1d3912028")

    {:ok, view, _html} = live(conn, ~p"/matches?nickname=stefan")

    assert has_element?(
             view,
             "#recent-matches a[href='/matches/1-66a72de6-070d-4308-966f-eea1d3912028?nickname=stefan']",
             "Mirage"
           )
  end

  test "renders an empty state without a nickname", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/matches")

    assert has_element?(view, "#matches-empty")
    refute has_element?(view, "#matches-player-card")
    refute has_element?(view, "#recent-matches")
  end

  defp update_match_id!(from_id, to_id) do
    from_id
    |> match_by_faceit_id!()
    |> Match.changeset(%{faceit_match_id: to_id})
    |> Repo.update!()
  end

  defp match_by_faceit_id!(faceit_match_id) do
    Repo.get_by!(Match, faceit_match_id: faceit_match_id)
  end
end
