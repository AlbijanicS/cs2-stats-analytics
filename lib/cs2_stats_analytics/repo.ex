defmodule Cs2StatsAnalytics.Repo do
  use Ecto.Repo,
    otp_app: :cs2_stats_analytics,
    adapter: Ecto.Adapters.Postgres
end
