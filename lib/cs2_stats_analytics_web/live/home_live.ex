defmodule Cs2StatsAnalyticsWeb.HomeLive do
  @moduledoc """
  Landing page for starting a CS2 player analytics search.
  """

  use Cs2StatsAnalyticsWeb, :live_view

  alias Cs2StatsAnalytics.Analytics

  @dashboard_match_limit 30

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:form, to_form(%{"nickname" => ""}, as: :search))
      |> assign(:status, :idle)
      |> assign(:error, nil)
      |> assign(:loading_nickname, nil)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} active_nav={:home} show_sidebar={false}>
      <section
        id="home-landing"
        class="relative flex min-h-screen items-center justify-center overflow-hidden bg-black px-4 py-14 sm:px-8"
      >
        <div class="absolute inset-0 bg-[radial-gradient(circle_at_50%_0%,rgba(249,115,22,0.18),transparent_34%),linear-gradient(180deg,rgba(39,39,42,0.48),rgba(9,9,11,0.2)_42%,rgba(0,0,0,0.86))]">
        </div>

        <div class="relative z-10 mx-auto flex w-full max-w-4xl flex-col items-center text-center">
          <p class="text-xs font-semibold uppercase tracking-[0.28em] text-orange-400">
            FACEIT performance intelligence
          </p>

          <h1 class="mt-6 max-w-full overflow-hidden text-4xl font-black tracking-tight text-white sm:text-6xl lg:text-7xl">
            <span class="typewriter">Welcome to CS2 Analytics</span>
          </h1>

          <p class="mt-6 max-w-2xl text-base leading-7 text-zinc-300 sm:text-lg">
            Search a player nickname to view recent performance, trends, and match history.
          </p>

          <.form
            for={@form}
            id="home-search-form"
            phx-submit="search"
            class="mx-auto mt-10 flex w-full max-w-2xl flex-col justify-center gap-3 rounded-xl border border-zinc-800 bg-zinc-950/85 p-3 shadow-2xl shadow-black/40 backdrop-blur sm:flex-row [&>div]:mb-0 sm:[&>div]:flex-1"
          >
            <.input
              field={@form[:nickname]}
              type="text"
              placeholder="Enter FACEIT nickname"
              class="h-14 w-full rounded-lg border border-zinc-700 bg-black px-5 text-base text-white shadow-inner shadow-black/40 outline-none transition placeholder:text-zinc-500 focus:border-orange-500 focus:bg-zinc-950 focus:ring-4 focus:ring-orange-500/15 sm:flex-1"
            />

            <.button
              type="submit"
              variant="primary"
              disabled={@status == :loading}
              class="inline-flex h-14 items-center justify-center gap-2 rounded-lg bg-orange-600 px-6 text-sm font-bold uppercase tracking-wide text-white shadow-lg shadow-orange-950/30 transition hover:-translate-y-0.5 hover:bg-orange-500 disabled:pointer-events-none disabled:opacity-60"
            >
              <.icon
                name={if(@status == :loading, do: "hero-arrow-path", else: "hero-magnifying-glass")}
                class={[
                  "size-5",
                  @status == :loading && "motion-safe:animate-spin"
                ]}
              /> Search
            </.button>
          </.form>

          <p
            :if={@status == :loading}
            id="home-dashboard-loading"
            class="mt-7 min-h-6 text-sm font-medium text-zinc-300 sm:text-base"
          >
            <span class="loading-typewriter">Fetching player stats...</span>
          </p>

          <p :if={@error} id="home-search-error" class="mt-4 text-sm font-medium text-orange-300">
            {@error}
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
          |> cancel_async(:prepare_dashboard)
          |> assign(:form, form)
          |> assign(:status, :error)
          |> assign(:error, "Enter a FACEIT nickname.")
          |> assign(:loading_nickname, nil)

        nickname ->
          socket
          |> cancel_async(:prepare_dashboard)
          |> assign(:form, form)
          |> assign(:status, :loading)
          |> assign(:error, nil)
          |> assign(:loading_nickname, nickname)
          |> start_async(:prepare_dashboard, fn ->
            {nickname, Analytics.get_or_sync_dashboard(nickname, @dashboard_match_limit)}
          end)
      end

    {:noreply, socket}
  end

  def handle_async(:prepare_dashboard, {:ok, {nickname, {:ok, _dashboard}}}, socket) do
    if socket.assigns.loading_nickname == nickname do
      {:noreply, push_navigate(socket, to: ~p"/dashboard?nickname=#{nickname}")}
    else
      {:noreply, socket}
    end
  end

  def handle_async(:prepare_dashboard, {:ok, {nickname, {:error, reason}}}, socket) do
    if socket.assigns.loading_nickname == nickname do
      socket =
        socket
        |> assign(:status, :error)
        |> assign(:error, error_message(reason))
        |> assign(:loading_nickname, nil)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_async(:prepare_dashboard, {:exit, {:shutdown, :cancel}}, socket) do
    {:noreply, socket}
  end

  def handle_async(:prepare_dashboard, {:exit, :cancel}, socket) do
    {:noreply, socket}
  end

  def handle_async(:prepare_dashboard, {:exit, _reason}, socket) do
    socket =
      socket
      |> assign(:status, :error)
      |> assign(:error, "Something went wrong while preparing the dashboard.")
      |> assign(:loading_nickname, nil)

    {:noreply, socket}
  end

  defp error_message(:player_not_found), do: "No FACEIT player found for that nickname."
  defp error_message(:player_history_not_found), do: "No recent FACEIT match history found."
  defp error_message(:match_stats_not_found), do: "Could not load match statistics."
  defp error_message(:no_recent_stats), do: "No recent stats are available for this player yet."
  defp error_message(message) when is_binary(message), do: message
  defp error_message(_reason), do: "Could not load that player. Check the nickname and try again."
end
