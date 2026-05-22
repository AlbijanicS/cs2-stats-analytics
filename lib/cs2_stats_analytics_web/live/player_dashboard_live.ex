defmodule Cs2StatsAnalyticsWeb.PlayerDashboardLive do
  use Cs2StatsAnalyticsWeb, :live_view

  alias Cs2StatsAnalytics.Analytics

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:form, to_form(%{"nickname" => ""}, as: :search))
      |> assign(:dashboard, nil)
      |> assign(:error, nil)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <section class="rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm">
        <h1 class="text-3xl font-bold text-zinc-900">
          CS2 FACEIT Analytics
        </h1>

        <p class="mt-2 text-zinc-600">
          Search a FACEIT nickname to view recent CS2 performance.
        </p>

        <.form
          for={@form}
          id="player-search-form"
          phx-submit="search"
          class="mt-6 flex flex-col gap-3 sm:flex-row"
        >
          <.input
            field={@form[:nickname]}
            type="text"
            placeholder="Enter FACEIT nickname"
            class="w-full rounded-lg border border-zinc-300 px-4 py-2 sm:flex-1"
          />

          <.button
            type="submit"
            variant="primary"
            class="rounded-lg bg-zinc-900 px-5 py-2 font-medium text-white"
          >
            Find stats
          </.button>
        </.form>

        <p :if={@error} id="dashboard-error" class="mt-4 text-sm text-red-600">
          {@error}
        </p>
      </section>

      <section
        :if={@dashboard}
        id="dashboard-summary"
        class="mt-6 grid gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:grid-cols-3"
      >
        <div>
          <p class="text-sm text-zinc-500">Player</p>
          <p class="mt-1 text-xl font-semibold text-zinc-900">{@dashboard.player.nickname}</p>
        </div>

        <div>
          <p class="text-sm text-zinc-500">Matches</p>
          <p class="mt-1 text-xl font-semibold text-zinc-900">
            {@dashboard.averages.matches_played}
          </p>
        </div>

        <div>
          <p class="text-sm text-zinc-500">Win rate</p>
          <p class="mt-1 text-xl font-semibold text-zinc-900">
            {@dashboard.averages.win_rate}%
          </p>
        </div>
      </section>
    </Layouts.app>
    """
  end

  def handle_event("search", %{"search" => %{"nickname" => nickname}}, socket) do
    nickname = String.trim(nickname)
    form = to_form(%{"nickname" => nickname}, as: :search)

    socket =
      case nickname do
        "" ->
          socket
          |> assign(:form, form)
          |> assign(:dashboard, nil)
          |> assign(:error, "Enter a FACEIT nickname.")

        nickname ->
          load_dashboard(socket, nickname, form)
      end

    {:noreply, socket}
  end

  defp load_dashboard(socket, nickname, form) do
    with {:ok, dashboard} <- Analytics.get_or_sync_dashboard(nickname, 3) do
      socket
      |> assign(:form, form)
      |> assign(:dashboard, dashboard)
      |> assign(:error, nil)
    else
      {:error, reason} ->
        socket
        |> assign(:form, form)
        |> assign(:dashboard, nil)
        |> assign(:error, error_message(reason))
    end
  end

  defp error_message(:player_not_found), do: "No FACEIT player found for that nickname."
  defp error_message(:player_history_not_found), do: "No recent FACEIT match history found."
  defp error_message(:match_stats_not_found), do: "Could not load match statistics."
  defp error_message(:no_recent_stats), do: "No recent stats are available for this player yet."
  defp error_message(_reason), do: "Could not load the dashboard."
end
