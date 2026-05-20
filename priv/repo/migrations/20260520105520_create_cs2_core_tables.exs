defmodule Cs2StatsAnalytics.Repo.Migrations.CreateCs2CoreTables do
  use Ecto.Migration

  def change do
    create table(:players) do
      add :faceit_player_id, :string, null: false
      add :nickname, :string, null: false
      add :steam_id, :string
      add :avatar_url, :string
      add :country, :string
      add :skill_level, :integer
      add :faceit_elo, :integer
      add :last_synced_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:players, [:faceit_player_id])
    create index(:players, [:nickname])

    create table(:matches) do
      add :faceit_match_id, :string, null: false
      add :game, :string, null: false, default: "cs2"
      add :map, :string
      add :started_at, :utc_datetime
      add :finished_at, :utc_datetime
      add :winner, :string
      add :score_faction1, :integer
      add :score_faction2, :integer
      add :raw_payload, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:matches, [:faceit_match_id])
    create index(:matches, [:finished_at])

    create table(:player_match_stats) do
      add :player_id, references(:players, on_delete: :delete_all), null: false
      add :match_id, references(:matches, on_delete: :delete_all), null: false

      add :team_id, :string
      add :nickname_at_match, :string

      add :kills, :integer
      add :deaths, :integer
      add :assists, :integer
      add :adr, :float
      add :headshots, :integer
      add :headshot_percent, :float
      add :kd_ratio, :float
      add :kr_ratio, :float
      add :mvps, :integer
      add :triple_kills, :integer
      add :quadro_kills, :integer
      add :penta_kills, :integer
      add :won, :boolean
      add :raw_stats, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:player_match_stats, [:player_id, :match_id])
    create index(:player_match_stats, [:player_id])
    create index(:player_match_stats, [:match_id])
  end
end
