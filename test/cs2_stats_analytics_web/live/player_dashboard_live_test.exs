defmodule Cs2StatsAnalyticsWeb.PlayerDashboardLiveTest do
  use Cs2StatsAnalyticsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

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

    assert has_element?(
             view,
             "#performance-trend-chart[phx-hook='AdrTrendChart'][phx-update='ignore'][data-points]"
           )

    assert has_element?(
             view,
             "#aim-trend-chart[phx-hook='HeadshotTrendChart'][phx-update='ignore'][data-points]"
           )
  end

  test "renders an error for blank search", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#player-search-form", search: %{nickname: "   "})
    |> render_submit()

    assert has_element?(view, "#dashboard-error", "Enter a FACEIT nickname.")
  end
end
