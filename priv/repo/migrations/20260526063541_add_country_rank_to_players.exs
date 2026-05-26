defmodule Cs2StatsAnalytics.Repo.Migrations.AddCountryRankToPlayers do
  use Ecto.Migration

  def change do
    alter table(:players) do
      add :country_rank, :integer
    end
  end
end
