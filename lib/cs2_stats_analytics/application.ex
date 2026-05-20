defmodule Cs2StatsAnalytics.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Cs2StatsAnalyticsWeb.Telemetry,
      Cs2StatsAnalytics.Repo,
      {DNSCluster,
       query: Application.get_env(:cs2_stats_analytics, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Cs2StatsAnalytics.PubSub},
      # Start a worker by calling: Cs2StatsAnalytics.Worker.start_link(arg)
      # {Cs2StatsAnalytics.Worker, arg},
      # Start to serve requests, typically the last entry
      Cs2StatsAnalyticsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Cs2StatsAnalytics.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    Cs2StatsAnalyticsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
