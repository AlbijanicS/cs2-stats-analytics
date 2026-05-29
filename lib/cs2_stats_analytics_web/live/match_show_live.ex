defmodule Cs2StatsAnalyticsWeb.MatchShowLive do
  @moduledoc """
  Minimal match show page backed by stored match stats.
  """

  use Cs2StatsAnalyticsWeb, :live_view

  alias Cs2StatsAnalytics.Analytics

  def mount(%{"faceit_match_id" => faceit_match_id} = params, _session, socket) do
    dashboard_path = dashboard_path(params)

    socket =
      case Analytics.get_match_scoreboard(faceit_match_id) do
        {:ok, scoreboard} ->
          socket
          |> assign(:scoreboard, scoreboard)
          |> assign(:error, nil)

        {:error, reason} ->
          socket
          |> assign(:scoreboard, nil)
          |> assign(:error, error_message(reason))
      end
      |> assign(:dashboard_path, dashboard_path)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-zinc-950 p-3 text-white shadow-2xl shadow-black/30 lg:flex lg:gap-5">
        <.sidebar dashboard_path={@dashboard_path} />

        <main class="mt-4 min-w-0 flex-1 lg:mt-0">
          <section
            :if={@error}
            id="match-scoreboard-error"
            class="rounded-xl border border-zinc-800 bg-zinc-900 p-6 shadow-lg shadow-black/20"
          >
            <.link
              navigate={@dashboard_path}
              class="text-sm font-semibold text-orange-400 hover:text-orange-300"
            >
              Back to dashboard
            </.link>

            <h1 class="mt-6 text-2xl font-bold">Match unavailable</h1>
            <p class="mt-2 text-zinc-400">{@error}</p>
          </section>

          <section :if={@scoreboard} id="match-scoreboard" class="space-y-4">
            <header class="rounded-xl border border-zinc-800 bg-zinc-900 p-5 shadow-lg shadow-black/20">
              <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
                <div>
                  <.link
                    navigate={@dashboard_path}
                    class="text-sm font-semibold text-orange-400 hover:text-orange-300"
                  >
                    Back to dashboard
                  </.link>

                  <p class="mt-5 text-sm font-medium uppercase tracking-[0.2em] text-zinc-500">
                    Matchroom
                  </p>
                  <h1 class="mt-1 text-3xl font-bold tracking-tight text-white">
                    {@scoreboard.pretty_map_name}
                  </h1>
                </div>

                <div class="flex items-center gap-4 rounded-xl border border-zinc-800 bg-black px-5 py-3">
                  <.score_block
                    label={team_name(@scoreboard.teams, "faction1")}
                    value={@scoreboard.score.faction1}
                  />
                  <span class="text-sm font-bold text-zinc-500">VS</span>
                  <.score_block
                    label={team_name(@scoreboard.teams, "faction2")}
                    value={@scoreboard.score.faction2}
                  />
                </div>
              </div>
            </header>

            <div class="space-y-4">
              <.team_scoreboard :for={team <- @scoreboard.teams} team={team} />
            </div>
          </section>
        </main>
      </div>
    </Layouts.app>
    """
  end

  attr :dashboard_path, :string, required: true

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
        <.nav_item icon="hero-squares-2x2" label="Dashboard" navigate={@dashboard_path} />
        <.nav_item icon="hero-table-cells" label="Matches" active />
        <.nav_item icon="hero-bolt" label="Aim" />
        <.nav_item icon="hero-wrench-screwdriver" label="Utility" />
        <.nav_item icon="hero-chart-bar-square" label="Impact" />
        <.nav_item icon="hero-map" label="Maps" />
        <.nav_item icon="hero-cog-6-tooth" label="Settings" />
      </nav>
    </aside>
    """
  end

  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :navigate, :string, default: nil

  defp nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center gap-2 rounded-lg px-3 py-2.5 transition",
        if(@active,
          do: "bg-orange-600 text-white shadow-sm shadow-orange-950/30",
          else: "text-zinc-300 hover:bg-white/10 hover:text-white"
        )
      ]}
    >
      <.icon name={@icon} class="size-4 shrink-0" />
      <span class="truncate">{@label}</span>
    </.link>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp score_block(assigns) do
    ~H"""
    <div class="text-center">
      <p class="text-xs font-medium uppercase tracking-wide text-zinc-500">{@label}</p>
      <p class="mt-1 text-3xl font-bold text-white">{@value || "-"}</p>
    </div>
    """
  end

  attr :team, :map, required: true

  defp team_scoreboard(assigns) do
    ~H"""
    <section class="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900 shadow-lg shadow-black/20">
      <div class="flex items-center justify-between gap-4 border-b border-zinc-800 bg-black px-5 py-4">
        <div class="flex items-center gap-3">
          <span class={[
            "text-2xl font-bold",
            if(@team.won, do: "text-emerald-400", else: "text-zinc-500")
          ]}>
            {@team.score || "-"}
          </span>
          <h2 class="text-lg font-bold text-white">{@team.name}</h2>
        </div>

        <span
          :if={@team.won}
          class="rounded-full bg-emerald-500/10 px-3 py-1 text-xs font-semibold text-emerald-300"
        >
          Winner
        </span>
      </div>

      <div class="overflow-x-auto">
        <table class="w-full min-w-[44rem] text-left text-sm">
          <thead class="bg-zinc-900 text-xs uppercase tracking-wide text-zinc-500">
            <tr>
              <th class="px-5 py-3 font-semibold">Player</th>
              <th class="px-4 py-3 font-semibold">K / D / A</th>
              <th class="px-4 py-3 font-semibold">ADR</th>
              <th class="px-4 py-3 font-semibold">K/D</th>
              <th class="px-4 py-3 font-semibold">HS%</th>
              <th class="px-4 py-3 font-semibold">MVPs</th>
            </tr>
          </thead>

          <tbody class="divide-y divide-zinc-800 bg-black text-zinc-300">
            <tr :for={player <- @team.players} class="hover:bg-zinc-900/80">
              <td class="px-5 py-4 font-semibold text-white">{player.nickname}</td>
              <td class="px-4 py-4">
                {stat_value(player.kills)} / {stat_value(player.deaths)} / {stat_value(player.assists)}
              </td>
              <td class="px-4 py-4">{stat_value(player.adr)}</td>
              <td class="px-4 py-4">{stat_value(player.kd_ratio)}</td>
              <td class="px-4 py-4">{stat_value(player.headshot_percent)}%</td>
              <td class="px-4 py-4">{stat_value(player.mvps)}</td>
            </tr>

            <tr :if={@team.players == []}>
              <td colspan="6" class="px-5 py-5 text-zinc-500">
                No stored player rows for this faction yet.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  defp stat_value(nil), do: "-"
  defp stat_value(value), do: value

  defp team_name(teams, faction) do
    teams
    |> Enum.find(&(&1.faction == faction))
    |> case do
      nil -> faction
      team -> team.name
    end
  end

  defp dashboard_path(%{"nickname" => nickname}) do
    case String.trim(nickname) do
      "" -> ~p"/"
      nickname -> ~p"/?nickname=#{nickname}"
    end
  end

  defp dashboard_path(_params), do: ~p"/"

  defp error_message(:match_not_found), do: "No stored match was found for this FACEIT match id."

  defp error_message(:scoreboard_not_available),
    do: "This match does not have enough stored raw stats to build a scoreboard yet."

  defp error_message(_reason), do: "Could not load this match."
end
