defmodule Cs2StatsAnalyticsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use Cs2StatsAnalyticsWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :active_nav, :atom, default: :dashboard
  attr :nickname, :string, default: ""
  attr :show_sidebar, :boolean, default: true

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main class={[
      "min-h-screen bg-zinc-950 text-white",
      @show_sidebar && "p-3 shadow-2xl shadow-black/30 lg:flex lg:gap-5"
    ]}>
      <.sidebar :if={@show_sidebar} active_nav={@active_nav} nickname={@nickname} />

      <div class={["min-w-0 flex-1", @show_sidebar && "mt-4 lg:mt-0"]}>
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  attr :active_nav, :atom, required: true
  attr :nickname, :string, required: true

  defp sidebar(assigns) do
    assigns =
      assigns
      |> assign(:dashboard_path, dashboard_path(assigns.nickname))
      |> assign(:matches_path, matches_path(assigns.nickname))

    ~H"""
    <aside
      id="dashboard-sidebar"
      class="rounded-xl border border-zinc-800 bg-black p-4 text-white shadow-lg shadow-black/40 lg:sticky lg:top-3 lg:h-[calc(100vh-1.5rem)] lg:w-64 lg:shrink-0"
    >
      <div class="flex items-center justify-between gap-3 lg:block">
        <.link
          navigate={~p"/"}
          class="block rounded-lg transition hover:opacity-85 focus:outline-none focus:ring-2 focus:ring-orange-500/60 focus:ring-offset-2 focus:ring-offset-black"
          aria-label="Go to front page"
        >
          <p class="text-xs font-semibold uppercase tracking-[0.24em] text-orange-400">
            FACEIT
          </p>
          <h1 class="mt-1 text-2xl font-bold tracking-tight">CS2 Analytics</h1>
        </.link>
      </div>

      <nav
        id="dashboard-nav"
        class="mt-5 grid grid-cols-2 gap-2 text-sm font-medium sm:grid-cols-4 lg:grid-cols-1"
      >
        <.nav_item
          icon="hero-squares-2x2"
          label="Dashboard"
          navigate={@dashboard_path}
          active={@active_nav == :dashboard}
        />
        <.nav_item
          icon="hero-table-cells"
          label="Matches"
          navigate={@matches_path}
          active={@active_nav == :matches}
        />
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
      :if={@navigate}
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

    <span
      :if={!@navigate}
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
    </span>
    """
  end

  defp dashboard_path(nickname) do
    case String.trim(nickname) do
      "" -> ~p"/dashboard"
      nickname -> ~p"/dashboard?nickname=#{nickname}"
    end
  end

  defp matches_path(nickname) do
    case String.trim(nickname) do
      "" -> ~p"/matches"
      nickname -> ~p"/matches?nickname=#{nickname}"
    end
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
