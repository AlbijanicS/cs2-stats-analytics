defmodule Cs2StatsAnalyticsWeb.MatchShowLive do
  @moduledoc """
  Minimal match show page backed by stored match stats.
  """

  use Cs2StatsAnalyticsWeb, :live_view

  alias Cs2StatsAnalytics.Analytics

  def mount(%{"faceit_match_id" => faceit_match_id} = params, _session, socket) do
    dashboard_path = dashboard_path(params)
    nickname = params |> Map.get("nickname", "") |> String.trim()

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
      |> assign(:nickname, nickname)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active_nav={:matches} nickname={@nickname}>
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

        <.match_leaders leaders={@scoreboard.leaders} />

        <div class="space-y-4">
          <.team_scoreboard :for={team <- @scoreboard.teams} team={team} />
        </div>
      </section>
    </Layouts.app>
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

  attr :leaders, :map, required: true

  defp match_leaders(assigns) do
    assigns = assign(assigns, :leader_cards, leader_cards(assigns.leaders))

    ~H"""
    <section
      id="match-leaders"
      class="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-950 shadow-2xl shadow-black/30"
    >
      <div class="flex items-center justify-between gap-4 border-b border-zinc-800/80 bg-zinc-900/80 px-5 py-4">
        <div>
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-orange-400">
            Match Leaders
          </p>
          <h2 class="mt-1 text-xl font-bold tracking-tight text-white">Top performers</h2>
        </div>

        <div class="hidden items-center gap-2 rounded-full border border-orange-500/20 bg-orange-500/10 px-3 py-1.5 text-xs font-semibold text-orange-200 sm:flex">
          <span class="h-1.5 w-1.5 rounded-full bg-orange-400 shadow-[0_0_12px_rgba(251,146,60,0.9)]">
          </span>
          Round impact
        </div>
      </div>

      <div class="grid gap-3 p-3 sm:grid-cols-2 xl:grid-cols-5">
        <article
          :for={leader <- @leader_cards}
          id={"match-leader-#{leader.key}"}
          class="group relative overflow-hidden rounded-xl border border-zinc-800 bg-black p-4 shadow-lg shadow-black/20 transition duration-200 hover:-translate-y-0.5 hover:border-orange-500/50 hover:bg-zinc-950"
        >
          <div class={[
            "absolute inset-y-0 left-0 w-1",
            leader_accent_class(leader.key)
          ]}>
          </div>

          <div class="min-w-0">
            <p class="text-[0.68rem] font-bold uppercase tracking-[0.2em] text-zinc-500">
              {leader.label}
            </p>
            <p class="mt-3 truncate text-lg font-extrabold tracking-tight text-white">
              {leader.nickname || "-"}
            </p>
          </div>

          <div class="mt-5 flex items-end justify-between gap-3">
            <div class="min-w-0">
              <p class="text-3xl font-black leading-none tracking-tight text-white">
                {leader_value(leader)}
              </p>
              <p class="mt-1 text-sm font-medium text-zinc-400">{leader.detail}</p>
            </div>

            <div class="hidden h-10 w-10 shrink-0 items-center justify-center rounded-full border border-zinc-800 bg-zinc-900/80 text-sm font-black text-zinc-500 sm:flex">
              {leader_initials(leader.nickname)}
            </div>
          </div>
        </article>
      </div>
    </section>
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
              <td class="px-5 py-4">
                <.link
                  navigate={player_dashboard_path(player)}
                  class="font-semibold text-white transition hover:text-orange-400"
                >
                  {player.nickname}
                </.link>
              </td>
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
      "" -> ~p"/dashboard"
      nickname -> ~p"/dashboard?nickname=#{nickname}"
    end
  end

  defp dashboard_path(_params), do: ~p"/dashboard"

  defp player_dashboard_path(%{nickname: nickname}), do: ~p"/dashboard?nickname=#{nickname}"

  defp leader_cards(leaders) when is_map(leaders) do
    [
      {:top_fragger, "Top Fragger"},
      {:highest_adr, "Highest ADR"},
      {:best_kd, "Best K/D"},
      {:most_headshots, "Most Headshots"},
      {:most_utility_damage, "Most Utility Damage"}
    ]
    |> Enum.map(fn {key, label} ->
      leader =
        Map.get(leaders, key) ||
          %{label: label, nickname: nil, value: nil, detail: "No data"}

      Map.put(leader, :key, key)
    end)
  end

  defp leader_cards(_leaders), do: leader_cards(%{})

  defp leader_value(%{value: nil}), do: "-"

  defp leader_value(%{value: value}) when is_float(value) do
    value
    |> :erlang.float_to_binary(decimals: 2)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp leader_value(%{value: value}), do: to_string(value)

  defp leader_initials(nil), do: "-"

  defp leader_initials(nickname) do
    nickname
    |> String.trim()
    |> String.first()
    |> case do
      nil -> "-"
      initial -> String.upcase(initial)
    end
  end

  defp leader_accent_class(:most_utility_damage), do: "bg-cyan-400"
  defp leader_accent_class(:best_kd), do: "bg-emerald-400"
  defp leader_accent_class(_key), do: "bg-orange-500"

  defp error_message(:match_not_found), do: "No stored match was found for this FACEIT match id."

  defp error_message(:scoreboard_not_available),
    do: "This match does not have enough stored raw stats to build a scoreboard yet."

  defp error_message(_reason), do: "Could not load this match."
end
