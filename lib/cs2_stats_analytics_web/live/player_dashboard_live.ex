defmodule Cs2StatsAnalyticsWeb.PlayerDashboardLive do
  @moduledoc """
  LiveView for searching a FACEIT nickname and rendering the analytics dashboard.

  The LiveView owns form state and presentation only. It calls
  `Cs2StatsAnalytics.Analytics` for all sync and read decisions, keeping FACEIT
  client, normalization, import, and query details out of the UI layer.
  """

  use Cs2StatsAnalyticsWeb, :live_view

  alias Cs2StatsAnalytics.Analytics

  @dashboard_match_limit 10

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:form, to_form(%{"nickname" => ""}, as: :search))
      |> assign(:dashboard, nil)
      |> assign(:status, :empty)
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
            phx-disable-with="Fetching..."
            class="rounded-lg bg-zinc-900 px-5 py-2 font-medium text-white"
          >
            Find stats
          </.button>
        </.form>

        <p :if={@status == :loading} id="dashboard-loading" class="mt-4 text-sm text-zinc-600">
          Fetching stats...
        </p>

        <p :if={@error} id="dashboard-error" class="mt-4 text-sm text-red-600">
          {@error}
        </p>
      </section>

      <section
        :if={@dashboard}
        id="dashboard-summary"
        class="mt-6 grid gap-4 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm sm:grid-cols-3 lg:grid-cols-6"
      >
        <.stat_card label="Player" value={@dashboard.player.nickname} />
        <.stat_card label="Matches" value={@dashboard.averages.matches_played} />
        <.stat_card label="Win rate" value={"#{@dashboard.averages.win_rate}%"} />
        <.stat_card label="Avg Kills" value={@dashboard.averages.avg_kills} />
        <.stat_card label="Avg ADR" value={@dashboard.averages.avg_adr} />
        <.stat_card label="Avg K/D" value={@dashboard.averages.avg_kd_ratio} />
      </section>

      <section
        :if={@dashboard}
        id="latest-match-summary"
        class="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
      >
        <h2 class="text-xl font-semibold text-zinc-900">
          Latest Match
        </h2>

        <div class="mt-4 grid gap-4 sm:grid-cols-2 lg:grid-cols-5">
          <div>
            <p class="text-sm text-zinc-500">Map</p>
            <p class="mt-1 font-medium text-zinc-900">
              {@dashboard.latest_match_summary.map}
            </p>
          </div>

          <div>
            <p class="text-sm text-zinc-500">Result</p>
            <p class="mt-1 font-medium text-zinc-900">
              {if @dashboard.latest_match_summary.won, do: "Win", else: "Loss"}
            </p>
          </div>

          <div>
            <p class="text-sm text-zinc-500">K / D / A</p>
            <p class="mt-1 font-medium text-zinc-900">
              {@dashboard.latest_match_summary.kills} / {@dashboard.latest_match_summary.deaths} / {@dashboard.latest_match_summary.assists}
            </p>
          </div>

          <div>
            <p class="text-sm text-zinc-500">ADR</p>
            <p class="mt-1 font-medium text-zinc-900">
              {@dashboard.latest_match_summary.adr}
            </p>
          </div>

          <div>
            <p class="text-sm text-zinc-500">K/D</p>
            <p class="mt-1 font-medium text-zinc-900">
              {@dashboard.latest_match_summary.kd_ratio}
            </p>
          </div>
        </div>
      </section>

      <section
        :if={@dashboard}
        id="performance-trend-chart-section"
        class="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
      >
        <h2 class="text-xl font-semibold text-zinc-900">
          ADR + K/D Trend
        </h2>

        <p class="mt-1 text-sm text-zinc-500">
          ADR and K/D trend from oldest match to newest match.
        </p>

        <div class="mt-5 h-72">
          <canvas
            id="performance-trend-chart"
            phx-hook="AdrTrendChart"
            phx-update="ignore"
            data-points={trend_chart_points(@dashboard)}
            class="h-full w-full"
          >
          </canvas>
        </div>
      </section>

      <section
        :if={@dashboard}
        id="aim-trend-chart-section"
        class="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
      >
        <h2 class="text-xl font-semibold text-zinc-900">
          Aim Trend
        </h2>

        <p class="mt-1 text-sm text-zinc-500">
          Headshot percentage from oldest match to newest match.
        </p>

        <div class="mt-5 h-72">
          <canvas
            id="aim-trend-chart"
            phx-hook="HeadshotTrendChart"
            phx-update="ignore"
            data-points={aim_chart_points(@dashboard)}
            class="h-full w-full"
          >
          </canvas>
        </div>
      </section>

      <section
        :if={@dashboard}
        id="recent-matches"
        class="mt-6 rounded-2xl border border-zinc-200 bg-white p-6 shadow-sm"
      >
        <h2 class="text-xl font-semibold text-zinc-900">
          Recent Matches
        </h2>

        <div class="mt-4 overflow-x-auto">
          <table class="w-full text-left text-sm">
            <thead class="border-b border-zinc-200 text-zinc-500">
              <tr>
                <th class="py-2 pr-4 font-medium">Map</th>
                <th class="py-2 pr-4 font-medium">Result</th>
                <th class="py-2 pr-4 font-medium">K / D / A</th>
                <th class="py-2 pr-4 font-medium">ADR</th>
                <th class="py-2 pr-4 font-medium">K/D</th>
                <th class="py-2 pr-4 font-medium">HS%</th>
              </tr>
            </thead>

            <tbody class="divide-y divide-zinc-100">
              <tr :for={stat <- @dashboard.recent_stats}>
                <td class="py-3 pr-4 font-medium text-zinc-900">
                  {stat.match.map}
                </td>

                <td class="py-3 pr-4">
                  {if stat.won, do: "Win", else: "Loss"}
                </td>

                <td class="py-3 pr-4">
                  {stat.kills} / {stat.deaths} / {stat.assists}
                </td>

                <td class="py-3 pr-4">
                  {stat.adr}
                </td>

                <td class="py-3 pr-4">
                  {stat.kd_ratio}
                </td>

                <td class="py-3 pr-4">
                  {stat.headshot_percent}%
                </td>
              </tr>
            </tbody>
          </table>
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
          |> assign(:status, :error)

        nickname ->
          socket
          |> assign(:form, form)
          |> assign(:dashboard, nil)
          |> assign(:error, nil)
          |> assign(:status, :loading)
          |> start_async(:load_dashboard, fn ->
            Analytics.get_or_sync_dashboard(nickname, @dashboard_match_limit)
          end)
      end

    {:noreply, socket}
  end

  def handle_async(:load_dashboard, {:ok, {:ok, dashboard}}, socket) do
    socket =
      socket
      |> assign(:dashboard, dashboard)
      |> assign(:error, nil)
      |> assign(:status, :loaded)

    {:noreply, socket}
  end

  def handle_async(:load_dashboard, {:ok, {:error, reason}}, socket) do
    socket =
      socket
      |> assign(:dashboard, nil)
      |> assign(:error, error_message(reason))
      |> assign(:status, :error)

    {:noreply, socket}
  end

  def handle_async(:load_dashboard, {:exit, _reason}, socket) do
    socket =
      socket
      |> assign(:dashboard, nil)
      |> assign(:error, "Something went wrong while loading the dashboard.")
      |> assign(:status, :error)

    {:noreply, socket}
  end

  defp trend_chart_points(dashboard) do
    dashboard.trends
    |> Enum.map(fn point ->
      %{
        label: point.label,
        adr: point.adr,
        kd_ratio: point.kd_ratio
      }
    end)
    |> Jason.encode!()
  end

  defp aim_chart_points(dashboard) do
    dashboard.trends
    |> Enum.map(fn point ->
      %{
        label: point.label,
        headshot_percent: point.headshot_percent
      }
    end)
    |> Jason.encode!()
  end

  defp error_message(:player_not_found), do: "No FACEIT player found for that nickname."
  defp error_message(:player_history_not_found), do: "No recent FACEIT match history found."
  defp error_message(:match_stats_not_found), do: "Could not load match statistics."
  defp error_message(:no_recent_stats), do: "No recent stats are available for this player yet."
  defp error_message(_reason), do: "Could not load the dashboard."

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp stat_card(assigns) do
    ~H"""
    <div>
      <p class="text-sm text-zinc-500">{@label}</p>
      <p class="mt-1 text-xl font-semibold text-zinc-900">
        {@value}
      </p>
    </div>
    """
  end
end
