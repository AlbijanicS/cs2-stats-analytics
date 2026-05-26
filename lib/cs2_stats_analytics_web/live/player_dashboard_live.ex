defmodule Cs2StatsAnalyticsWeb.PlayerDashboardLive do
  @moduledoc """
  LiveView for searching a FACEIT nickname and rendering the analytics dashboard.

  The LiveView owns form state and presentation only. It calls
  `Cs2StatsAnalytics.Analytics` for all sync and read decisions, keeping FACEIT
  client, normalization, import, and query details out of the UI layer.
  """

  use Cs2StatsAnalyticsWeb, :live_view

  alias Cs2StatsAnalytics.Analytics

  @dashboard_match_limit 30

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:form, to_form(%{"nickname" => ""}, as: :search))
      |> assign(:dashboard, nil)
      |> assign(:status, :empty)
      |> assign(:error, nil)
      |> assign(:loading_nickname, nil)
      |> assign(:active_chart, :performance)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-zinc-950 p-3 shadow-2xl shadow-black/30 lg:flex lg:gap-5">
        <.sidebar />

        <div class="mt-4 min-w-0 flex-1 lg:mt-0">
          <.search_panel form={@form} status={@status} error={@error} />

          <.dashboard_summary :if={@dashboard} dashboard={@dashboard} />

          <div :if={@dashboard} class="mt-4 grid gap-4 xl:grid-cols-[minmax(0,1fr)_18rem]">
            <.trend_chart_panel dashboard={@dashboard} active_chart={@active_chart} />
            <.latest_match_card dashboard={@dashboard} />
          </div>

          <.recent_matches_table :if={@dashboard} dashboard={@dashboard} />
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp sidebar(assigns) do
    ~H"""
    <aside
      id="dashboard-sidebar"
      class="rounded-xl border border-zinc-800 bg-black p-4 text-white shadow-lg shadow-black/40 lg:sticky lg:top-3 lg:h-[calc(100vh-1.5rem)] lg:w-64 lg:shrink-0"
    >
      <div class="flex items-center justify-between gap-3 lg:block">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-orange-400">
            FACEIT
          </p>
          <h1 class="mt-1 text-2xl font-bold tracking-tight">CS2 Analytics</h1>
        </div>
      </div>

      <nav
        id="dashboard-nav"
        class="mt-5 grid grid-cols-2 gap-2 text-sm font-medium sm:grid-cols-4 lg:grid-cols-1"
      >
        <.nav_item icon="hero-squares-2x2" label="Dashboard" active />
        <.nav_item icon="hero-table-cells" label="Matches" />
        <.nav_item icon="hero-bolt" label="Aim" />
        <.nav_item icon="hero-wrench-screwdriver" label="Utility" />
        <.nav_item icon="hero-chart-bar-square" label="Impact" />
        <.nav_item icon="hero-map" label="Maps" />
        <.nav_item icon="hero-cog-6-tooth" label="Settings" />
      </nav>
    </aside>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :status, :atom, required: true
  attr :error, :string, default: nil

  defp search_panel(assigns) do
    ~H"""
    <section class="rounded-xl border border-zinc-800 bg-zinc-900 p-4 shadow-lg shadow-black/20 sm:p-5">
      <div class="flex flex-col gap-4 xl:flex-row xl:items-center xl:justify-between">
        <div>
          <p class="text-sm font-medium text-orange-400">Player dashboard</p>
          <h2 class="mt-1 text-2xl font-bold tracking-tight text-white sm:text-3xl">
            Recent Statistics
          </h2>
        </div>

        <.form
          for={@form}
          id="player-search-form"
          phx-submit="search"
          class="flex w-full flex-col gap-3 sm:flex-row xl:max-w-xl"
        >
          <.input
            field={@form[:nickname]}
            type="text"
            placeholder="Enter FACEIT nickname"
            class="h-11 w-full rounded-lg border border-zinc-700 bg-black px-4 text-sm text-white shadow-inner shadow-black/40 outline-none transition placeholder:text-zinc-500 focus:border-orange-500 focus:bg-zinc-950 focus:ring-4 focus:ring-orange-500/15 sm:flex-1"
          />

          <.button
            type="submit"
            variant="primary"
            phx-disable-with="Fetching..."
            class="inline-flex h-11 items-center justify-center gap-2 rounded-lg bg-orange-600 px-5 text-sm font-semibold text-white shadow-sm shadow-orange-950/30 transition hover:bg-orange-500 disabled:pointer-events-none disabled:opacity-60"
          >
            <.icon name="hero-magnifying-glass" class="size-4" /> Search
          </.button>
        </.form>
      </div>

      <p :if={@status == :loading} id="dashboard-loading" class="mt-4 text-sm text-zinc-300">
        Fetching stats...
      </p>

      <p
        :if={@status == :refreshing}
        id="dashboard-refreshing"
        class="mt-4 flex items-center gap-2 text-sm text-zinc-300"
      >
        <.icon name="hero-arrow-path" class="size-4 text-orange-400 motion-safe:animate-spin" />
        Updating cached stats...
      </p>

      <p :if={@error} id="dashboard-error" class="mt-4 text-sm font-medium text-orange-300">
        {@error}
      </p>
    </section>
    """
  end

  attr :dashboard, :map, required: true

  defp dashboard_summary(assigns) do
    ~H"""
    <section
      id="dashboard-summary"
      class="mt-4 grid gap-4 xl:grid-cols-[minmax(0,0.9fr)_minmax(0,2.4fr)]"
    >
      <.player_summary dashboard={@dashboard} />
      <.average_stats dashboard={@dashboard} />
    </section>
    """
  end

  attr :dashboard, :map, required: true

  defp player_summary(assigns) do
    ~H"""
    <div class="rounded-xl border border-zinc-800 bg-zinc-900 p-5 shadow-lg shadow-black/20">
      <div class="flex items-center gap-4">
        <div class="flex size-16 shrink-0 items-center justify-center overflow-hidden rounded-xl bg-orange-600 text-xl font-bold text-white shadow-lg shadow-orange-950/30">
          <img
            :if={avatar_available?(@dashboard.player.avatar_url)}
            src={@dashboard.player.avatar_url}
            alt={"#{@dashboard.player.nickname} avatar"}
            class="h-full w-full object-cover"
          />

          <span :if={!avatar_available?(@dashboard.player.avatar_url)}>
            {player_initial(@dashboard.player.nickname)}
          </span>
        </div>

        <div class="min-w-0">
          <p class="text-sm text-zinc-400">Player</p>

          <div class="flex min-w-0 items-center gap-2">
            <p class="truncate text-xl font-bold text-white">
              {@dashboard.player.nickname}
            </p>

            <img
              :if={country_code(@dashboard.player.country) != ""}
              src={flag_icon_path(@dashboard.player.country)}
              alt={"#{country_code(@dashboard.player.country)} flag"}
              class="h-[18px] w-6 shrink-0 object-cover"
            />
          </div>

          <div class="mt-3 flex flex-wrap items-center gap-2">
            <span class={level_badge_class(@dashboard.player.skill_level)}>
              Level {@dashboard.player.skill_level || "?"}
            </span>

            <span class="rounded-full border border-zinc-700 px-3 py-1 text-xs font-medium text-zinc-300">
              {@dashboard.player.faceit_elo || "?"} ELO
            </span>

            <span
              :if={@dashboard.player.country_rank}
              class="rounded-full border border-orange-500/40 bg-orange-500/10 px-3 py-1 text-xs font-semibold uppercase text-orange-300"
            >
              {"##{@dashboard.player.country_rank} #{country_code(@dashboard.player.country)}"}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :dashboard, :map, required: true

  defp average_stats(assigns) do
    ~H"""
    <div class="rounded-xl border border-zinc-800 bg-zinc-900 p-5 shadow-lg shadow-black/20">
      <div class="flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p class="text-sm font-medium text-zinc-400">Average stats</p>
          <h2 class="text-xl font-bold text-white">
            Past {@dashboard.averages.matches_played} matches
          </h2>
        </div>
      </div>

      <div class="mt-5 grid grid-cols-2 gap-3 lg:grid-cols-6">
        <.stat_card label="Entry rate" value={entry_success_value(@dashboard)} />
        <.stat_card label="Win rate" value={"#{@dashboard.averages.win_rate}%"} />
        <.stat_card label="Avg K/D" value={@dashboard.averages.avg_kd_ratio} />
        <.stat_card
          label="Avg HS%"
          value={avg_headshot_percent(@dashboard.averages.avg_headshot_percent)}
        />
        <.stat_card label="Avg Kills" value={@dashboard.averages.avg_kills} />
        <.stat_card label="Avg ADR" value={@dashboard.averages.avg_adr} />
      </div>
    </div>
    """
  end

  attr :dashboard, :map, required: true
  attr :active_chart, :atom, required: true

  defp trend_chart_panel(assigns) do
    assigns =
      assigns
      |> assign(:active_chart_metadata, chart_metadata(assigns.active_chart))
      |> assign(:chart_tabs, chart_tabs())

    ~H"""
    <section
      id="performance-trend-chart-section"
      class="rounded-xl border border-zinc-800 bg-zinc-900 p-5 shadow-lg shadow-black/20"
    >
      <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
        <div>
          <h2 class="text-xl font-semibold text-white">
            {@active_chart_metadata.title}
          </h2>

          <p class="mt-1 text-sm text-zinc-400">
            {@active_chart_metadata.description}
          </p>
        </div>

        <div class="inline-flex rounded-lg border border-zinc-700 bg-black p-1 text-xs font-semibold text-zinc-400">
          <button
            :for={tab <- @chart_tabs}
            type="button"
            id={"#{tab.param}-chart-tab"}
            phx-click="select_chart"
            phx-value-chart={tab.param}
            class={chart_tab_class(@active_chart, tab.chart)}
          >
            {tab.label}
          </button>
        </div>
      </div>

      <div class="mt-5 h-72">
        <canvas
          :if={@active_chart == :performance}
          id="performance-trend-chart"
          phx-hook="AdrTrendChart"
          phx-update="ignore"
          data-points={trend_chart_points(@dashboard)}
          class="h-full w-full"
        >
        </canvas>

        <canvas
          :if={@active_chart == :aim}
          id="aim-trend-chart"
          phx-hook="HeadshotTrendChart"
          phx-update="ignore"
          data-points={aim_chart_points(@dashboard)}
          class="h-full w-full"
        >
        </canvas>
      </div>
    </section>
    """
  end

  attr :dashboard, :map, required: true

  defp latest_match_card(assigns) do
    assigns =
      assign(
        assigns,
        :map_metadata,
        map_metadata(assigns.dashboard.latest_match_summary.map)
      )

    ~H"""
    <section
      id="latest-match-summary"
      class="relative overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900 p-5 shadow-lg shadow-black/20"
    >
      <div
        :if={@map_metadata.image_url}
        class="absolute inset-0 bg-cover bg-center opacity-45"
        style={"background-image: url('#{@map_metadata.image_url}')"}
      >
      </div>

      <div class="absolute inset-0 bg-gradient-to-b from-zinc-950/30 via-zinc-950/50 to-zinc-950/85">
      </div>

      <div class="relative z-10">
        <p class="text-sm font-medium text-orange-400">Latest Match</p>
        <h2 class="mt-1 text-2xl font-bold text-white">
          {@map_metadata.name}
        </h2>

        <div class="mt-5 space-y-4">
          <.latest_metric
            label="Result"
            value={if @dashboard.latest_match_summary.won, do: "Win", else: "Loss"}
          />
          <.latest_metric
            label="K / D / A"
            value={"#{@dashboard.latest_match_summary.kills} / #{@dashboard.latest_match_summary.deaths} / #{@dashboard.latest_match_summary.assists}"}
          />
          <.latest_metric label="ADR" value={@dashboard.latest_match_summary.adr} />
          <.latest_metric label="K/D" value={@dashboard.latest_match_summary.kd_ratio} />
        </div>
      </div>
    </section>
    """
  end

  attr :dashboard, :map, required: true

  defp recent_matches_table(assigns) do
    ~H"""
    <section
      id="recent-matches"
      class="mt-4 rounded-xl border border-zinc-800 bg-zinc-900 p-5 shadow-lg shadow-black/20"
    >
      <div class="flex items-center justify-between gap-3">
        <h2 class="text-xl font-semibold text-white">
          Recent Matches
        </h2>

        <span class="rounded-full bg-orange-500/10 px-3 py-1 text-xs font-semibold text-orange-300">
          Last {@dashboard.averages.matches_played}
        </span>
      </div>

      <div class="mt-4 overflow-x-auto">
        <table class="w-full min-w-[42rem] text-left text-sm">
          <thead class="border-b border-zinc-800 text-xs uppercase tracking-wide text-zinc-500">
            <tr>
              <th class="py-3 pr-4 font-semibold">Map</th>
              <th class="py-3 pr-4 font-semibold">Result</th>
              <th class="py-3 pr-4 font-semibold">K / D / A</th>
              <th class="py-3 pr-4 font-semibold">ADR</th>
              <th class="py-3 pr-4 font-semibold">K/D</th>
              <th class="py-3 pr-4 font-semibold">HS%</th>
            </tr>
          </thead>

          <tbody class="divide-y divide-zinc-800 text-zinc-300">
            <tr :for={stat <- @dashboard.recent_stats} class="transition hover:bg-black/30">
              <td class="py-3 pr-4 font-semibold text-white">
                {stat.match.map}
              </td>

              <td class="py-3 pr-4">
                <span class={[
                  "rounded-full px-2.5 py-1 text-xs font-semibold",
                  if(stat.won,
                    do: "bg-emerald-500/10 text-emerald-300",
                    else: "bg-red-500/10 text-red-300"
                  )
                ]}>
                  {if stat.won, do: "Win", else: "Loss"}
                </span>
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
    """
  end

  def handle_event("search", %{"search" => %{"nickname" => nickname}}, socket) do
    nickname = String.trim(nickname)
    form = to_form(%{"nickname" => nickname}, as: :search)

    socket =
      case nickname do
        "" ->
          socket
          |> cancel_async(:load_dashboard)
          |> assign(:form, form)
          |> assign_dashboard_error("Enter a FACEIT nickname.")

        nickname ->
          socket
          |> cancel_async(:load_dashboard)
          |> assign(:form, form)
          |> load_dashboard(nickname)
      end

    {:noreply, socket}
  end

  def handle_event("select_chart", %{"chart" => chart}, socket) do
    case chart_from_param(chart) do
      {:ok, chart} -> {:noreply, assign(socket, :active_chart, chart)}
      :error -> {:noreply, socket}
    end
  end

  defp load_dashboard(socket, nickname) do
    case Analytics.get_dashboard_refresh_state(nickname, @dashboard_match_limit) do
      {:ok, :fresh, dashboard} ->
        assign_loaded_dashboard(socket, dashboard)

      {:ok, :stale, dashboard} ->
        socket
        |> assign_refreshing_dashboard(dashboard, nickname)
        |> start_async(:load_dashboard, fn ->
          {nickname, Analytics.get_or_sync_dashboard(nickname, @dashboard_match_limit)}
        end)

      {:error, _reason} ->
        socket
        |> assign_loading_dashboard(nickname)
        |> start_async(:load_dashboard, fn ->
          {nickname, Analytics.get_or_sync_dashboard(nickname, @dashboard_match_limit)}
        end)
    end
  end

  def handle_async(:load_dashboard, {:ok, {nickname, result}}, socket) do
    if socket.assigns.loading_nickname == nickname do
      handle_dashboard_result(result, socket)
    else
      {:noreply, socket}
    end
  end

  def handle_async(:load_dashboard, {:exit, {:shutdown, :cancel}}, socket) do
    {:noreply, socket}
  end

  def handle_async(:load_dashboard, {:exit, :cancel}, socket) do
    {:noreply, socket}
  end

  def handle_async(:load_dashboard, {:exit, _reason}, socket) do
    socket = assign_dashboard_error(socket, :unexpected_exit)

    {:noreply, socket}
  end

  defp handle_dashboard_result({:ok, dashboard}, socket) do
    {:noreply, assign_loaded_dashboard(socket, dashboard)}
  end

  defp handle_dashboard_result({:error, reason}, socket) do
    {:noreply, assign_dashboard_error(socket, reason)}
  end

  defp assign_loaded_dashboard(socket, dashboard) do
    socket
    |> assign(:dashboard, dashboard)
    |> assign(:error, nil)
    |> assign(:status, :loaded)
    |> assign(:loading_nickname, nil)
  end

  defp assign_loading_dashboard(socket, nickname) do
    socket
    |> assign(:dashboard, nil)
    |> assign(:error, nil)
    |> assign(:status, :loading)
    |> assign(:loading_nickname, nickname)
  end

  defp assign_refreshing_dashboard(socket, dashboard, nickname) do
    socket
    |> assign(:dashboard, dashboard)
    |> assign(:error, nil)
    |> assign(:status, :refreshing)
    |> assign(:loading_nickname, nickname)
  end

  defp assign_dashboard_error(%{assigns: %{dashboard: nil}} = socket, reason) do
    socket
    |> assign(:dashboard, nil)
    |> assign(:error, error_message(reason))
    |> assign(:status, :error)
    |> assign(:loading_nickname, nil)
  end

  defp assign_dashboard_error(socket, reason) do
    socket
    |> assign(:error, refresh_error_message(reason))
    |> assign(:status, :loaded)
    |> assign(:loading_nickname, nil)
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
  defp error_message(:unexpected_exit), do: "Something went wrong while loading the dashboard."
  defp error_message(message) when is_binary(message), do: message
  defp error_message(_reason), do: "Could not load the dashboard."

  defp refresh_error_message(_reason),
    do: "Could not refresh the dashboard. Showing cached stats."

  defp chart_tab_class(active_chart, chart) do
    base = "rounded-md px-3 py-1.5 transition"

    if active_chart == chart do
      "#{base} bg-orange-600 text-white shadow-sm"
    else
      "#{base} text-zinc-400 hover:text-white"
    end
  end

  defp chart_tabs do
    [
      chart_metadata(:performance),
      chart_metadata(:aim)
    ]
  end

  defp chart_from_param("performance"), do: {:ok, :performance}
  defp chart_from_param("aim"), do: {:ok, :aim}
  defp chart_from_param(_chart), do: :error

  defp chart_metadata(:aim) do
    %{
      chart: :aim,
      param: "aim",
      label: "Aim",
      title: "Aim Trend",
      description: "Headshot percentage trend from oldest match to newest match."
    }
  end

  defp chart_metadata(_chart) do
    %{
      chart: :performance,
      param: "performance",
      label: "ADR / K/D",
      title: "ADR + K/D Trend",
      description: "ADR and K/D trend from oldest match to newest match."
    }
  end

  defp map_metadata("de_ancient"),
    do: %{name: "Ancient", image_url: ~p"/assets/images/de_ancient.png"}

  defp map_metadata("de_anubis"), do: %{name: "Anubis", image_url: ~p"/assets/images/anubis.png"}
  defp map_metadata("de_dust2"), do: %{name: "Dust II", image_url: ~p"/assets/images/dust 2.png"}
  defp map_metadata("dust_2"), do: %{name: "Dust II", image_url: ~p"/assets/images/dust 2.png"}

  defp map_metadata("de_inferno"),
    do: %{name: "Inferno", image_url: ~p"/assets/images/inferno.png"}

  defp map_metadata("de_mirage"), do: %{name: "Mirage", image_url: ~p"/assets/images/mirage.png"}
  defp map_metadata("de_nuke"), do: %{name: "Nuke", image_url: ~p"/assets/images/nuke.png"}

  defp map_metadata("de_overpass"),
    do: %{name: "Overpass", image_url: ~p"/assets/images/overpass.png"}

  defp map_metadata(map), do: %{name: map, image_url: nil}

  defp avg_headshot_percent(nil), do: "--"
  defp avg_headshot_percent(value), do: "#{value}%"

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  defp nav_item(assigns) do
    ~H"""
    <span class={[
      "flex items-center gap-2 rounded-lg px-3 py-2.5 transition",
      if(@active,
        do: "bg-orange-600 text-white shadow-sm shadow-orange-950/30",
        else: "text-zinc-300 hover:bg-white/10 hover:text-white"
      )
    ]}>
      <.icon name={@icon} class="size-4 shrink-0" />
      <span class="truncate">{@label}</span>
    </span>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp latest_metric(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-800 bg-black px-4 py-3">
      <p class="text-xs font-medium uppercase tracking-wide text-zinc-500">{@label}</p>
      <p class="mt-1 text-lg font-semibold text-white">{@value}</p>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp stat_card(assigns) do
    ~H"""
    <div class="rounded-lg border border-zinc-800 bg-black px-4 py-3">
      <p class="text-xs font-medium uppercase tracking-wide text-zinc-500">{@label}</p>
      <p class="mt-1 text-xl font-semibold text-white">
        {@value}
      </p>
    </div>
    """
  end

  defp level_badge_class(skill_level) do
    base = "rounded-full px-3 py-1 text-xs font-bold uppercase tracking-wide text-white shadow-sm"

    color =
      case skill_level do
        10 -> "bg-red-600 shadow-red-950/30"
        9 -> "bg-orange-700 shadow-orange-950/30"
        8 -> "bg-orange-600 shadow-orange-950/30"
        level when level in [6, 7] -> "bg-yellow-500 text-zinc-950 shadow-yellow-950/20"
        5 -> "bg-lime-500 text-zinc-950 shadow-lime-950/20"
        4 -> "bg-lime-600 shadow-lime-950/20"
        level when level in [2, 3] -> "bg-green-600 shadow-green-950/20"
        1 -> "bg-zinc-700 shadow-black/20"
        _level -> "bg-zinc-700 shadow-black/20"
      end

    "#{base} #{color}"
  end

  defp country_code(nil), do: ""
  defp country_code(country_code), do: country_code |> String.trim() |> String.upcase()

  defp flag_icon_path(country_code),
    do: "/assets/flags/4x3/#{String.downcase(String.trim(country_code))}.svg"

  defp avatar_available?(nil), do: false
  defp avatar_available?(""), do: false
  defp avatar_available?(_avatar_url), do: true

  defp player_initial(nil), do: "?"

  defp player_initial(nickname) do
    nickname
    |> String.trim()
    |> String.first()
    |> case do
      nil -> "?"
      initial -> String.upcase(initial)
    end
  end

  defp entry_success_value(%{averages: %{avg_entry_success_percent: nil}}), do: "--"

  defp entry_success_value(%{averages: %{avg_entry_success_percent: value}}) do
    "#{value}%"
  end
end
