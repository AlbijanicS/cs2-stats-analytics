defmodule Cs2StatsAnalytics.Repo.Migrations.AddEntryStatsToPlayerMatchStats do
  use Ecto.Migration

  def change do
    alter table(:player_match_stats) do
      add :first_kills, :integer
      add :entry_count, :integer
      add :entry_wins, :integer
      add :entry_rate, :float
      add :entry_success_rate, :float
    end
  end
end
