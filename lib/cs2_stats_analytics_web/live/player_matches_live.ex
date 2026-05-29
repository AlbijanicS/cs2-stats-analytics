defmodule Cs2StatsAnalyticsWeb.PlayerMatchesLive do
  @moduledoc """
  LiveView for a player's recent match history.
  """

  use Cs2StatsAnalyticsWeb, :live_view

  alias Cs2StatsAnalytics.Analytics

  @match_limit 30

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:dashboard, nil)
      |> assign(:error, nil)
      |> assign(:nickname, "")
      |> assign(:status, :empty)

    {:ok, socket}
  end

  def handle_params(params, _uri, socket) do
    nickname = params |> Map.get("nickname", "") |> String.trim()

    socket =
      socket
      |> assign(:nickname, nickname)
      |> load_matches(nickname)

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active_nav={:matches} nickname={@nickname}>
      <section class="rounded-xl border border-zinc-800 bg-zinc-900 p-5 shadow-lg shadow-black/20">
        <p class="text-sm font-medium text-orange-400">Player matches</p>
        <h1 class="mt-1 text-2xl font-bold tracking-tight text-white sm:text-3xl">
          {matches_title(@dashboard, @nickname)}
        </h1>

        <p :if={@status == :loading} id="matches-loading" class="mt-4 text-sm text-zinc-300">
          Fetching matches...
        </p>

        <p :if={@status == :empty} id="matches-empty" class="mt-4 text-sm text-zinc-400">
          Search for a player on the dashboard to view match history.
        </p>

        <p :if={@error} id="matches-error" class="mt-4 text-sm font-medium text-orange-300">
          {@error}
        </p>
      </section>

      <.recent_matches_table :if={@dashboard} dashboard={@dashboard} />
    </Layouts.app>
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
                <.link
                  navigate={match_path(stat.match.faceit_match_id, @dashboard.player.nickname)}
                  class="text-white transition hover:text-orange-300"
                >
                  {map_metadata(stat.match.map).name}
                </.link>
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

  defp load_matches(socket, "") do
    socket
    |> assign(:dashboard, nil)
    |> assign(:error, nil)
    |> assign(:status, :empty)
  end

  defp load_matches(socket, nickname) do
    case Analytics.get_or_sync_dashboard(nickname, @match_limit) do
      {:ok, dashboard} ->
        socket
        |> assign(:dashboard, dashboard)
        |> assign(:error, nil)
        |> assign(:status, :loaded)

      {:error, reason} ->
        socket
        |> assign(:dashboard, nil)
        |> assign(:error, error_message(reason))
        |> assign(:status, :error)
    end
  end

  defp matches_title(%{player: player}, _nickname), do: "#{player.nickname}'s Match History"
  defp matches_title(_dashboard, ""), do: "Match History"
  defp matches_title(_dashboard, nickname), do: "#{nickname}'s Match History"

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

  defp match_path(faceit_match_id, nickname) do
    path = "/matches/#{URI.encode(to_string(faceit_match_id), &URI.char_unreserved?/1)}"

    case String.trim(nickname) do
      "" -> path
      nickname -> "#{path}?#{URI.encode_query(%{nickname: nickname})}"
    end
  end

  defp error_message(:player_not_found), do: "No FACEIT player found for that nickname."
  defp error_message(:player_history_not_found), do: "No recent FACEIT match history found."
  defp error_message(:match_stats_not_found), do: "Could not load match statistics."
  defp error_message(:no_recent_stats), do: "No recent stats are available for this player yet."
  defp error_message(_reason), do: "Could not load match history."
end
