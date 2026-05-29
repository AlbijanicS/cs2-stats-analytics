defmodule Cs2StatsAnalyticsWeb.HomeLiveTest do
  use Cs2StatsAnalyticsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  defmodule BlockingClient do
    def get_player_by_nickname("stefan") do
      test_pid = Application.fetch_env!(:cs2_stats_analytics, :live_view_test_pid)
      send(test_pid, {:home_lookup_started, self()})

      receive do
        :finish_home_lookup ->
          {:error, :player_not_found}
      end
    end

    def get_player_by_nickname(_nickname), do: {:error, :player_not_found}
    def get_player_history(_player_id, _limit), do: {:error, :unexpected_fetch}
    def get_match_stats(_match_id), do: {:error, :unexpected_fetch}
  end

  defmodule ErrorClient do
    def get_player_by_nickname(_nickname), do: {:error, :player_not_found}
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

  test "renders the landing search experience", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#home-landing")
    assert has_element?(view, "#home-search-form")
    assert has_element?(view, ".typewriter", "Welcome to CS2 Analytics")
    refute has_element?(view, "#dashboard-sidebar")
    refute has_element?(view, "#dashboard-summary")
  end

  test "shows landing loading state while preparing a nickname search", %{conn: conn} do
    Application.put_env(:cs2_stats_analytics, :live_view_test_pid, self())
    Application.put_env(:cs2_stats_analytics, :faceit_client, BlockingClient)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#home-search-form", search: %{nickname: " stefan "})
    |> render_submit()

    assert has_element?(view, "#home-dashboard-loading", "Fetching player stats...")
    assert_receive {:home_lookup_started, lookup_pid}

    send(lookup_pid, :finish_home_lookup)
    render_async(view)
  end

  test "navigates a nickname search to the dashboard query route after preparation succeeds", %{
    conn: conn
  } do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#home-search-form", search: %{nickname: " stefan "})
    |> render_submit()

    assert_redirect(view, ~p"/dashboard?nickname=stefan")
  end

  test "renders an error for blank landing search", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#home-search-form", search: %{nickname: "   "})
    |> render_submit()

    assert has_element?(view, "#home-search-error", "Enter a FACEIT nickname.")
  end

  test "stays on landing page and shows an error when preparation fails", %{conn: conn} do
    Application.put_env(:cs2_stats_analytics, :faceit_client, ErrorClient)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#home-search-form", search: %{nickname: "missing"})
    |> render_submit()

    render_async(view)

    assert has_element?(view, "#home-search-error", "No FACEIT player found for that nickname.")
    refute has_element?(view, "#home-dashboard-loading")
  end
end
