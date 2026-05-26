defmodule Cs2StatsAnalytics.Schemas.PlayerMatchStat do
  @moduledoc """
  Ecto schema for one player's stat line in one match.

  This table is the many-to-many join between players and matches with the
  additional performance metrics needed by the dashboard.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Cs2StatsAnalytics.Schemas.{Player, Match}

  @stat_fields [
    :team_id,
    :nickname_at_match,
    :kills,
    :deaths,
    :assists,
    :adr,
    :headshots,
    :headshot_percent,
    :kd_ratio,
    :kr_ratio,
    :mvps,
    :triple_kills,
    :quadro_kills,
    :penta_kills,
    :won,
    :raw_stats,
    :first_kills,
    :entry_count,
    :entry_wins,
    :entry_rate,
    :entry_success_rate
  ]

  @cast_fields [:player_id, :match_id | @stat_fields]

  schema "player_match_stats" do
    belongs_to :player, Player
    belongs_to :match, Match

    field :team_id, :string
    field :nickname_at_match, :string

    field :kills, :integer
    field :deaths, :integer
    field :assists, :integer
    field :adr, :float
    field :headshots, :integer
    field :headshot_percent, :float
    field :kd_ratio, :float
    field :kr_ratio, :float
    field :mvps, :integer
    field :triple_kills, :integer
    field :quadro_kills, :integer
    field :penta_kills, :integer
    field :won, :boolean
    field :raw_stats, :map
    field :first_kills, :integer
    field :entry_count, :integer
    field :entry_wins, :integer
    field :entry_rate, :float
    field :entry_success_rate, :float

    timestamps(type: :utc_datetime)
  end

  def stat_fields, do: @stat_fields

  def changeset(player_match_stat, attrs) do
    player_match_stat
    |> cast(attrs, @cast_fields)
    |> validate_required([:player_id, :match_id])
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:match_id)
    |> unique_constraint([:player_id, :match_id])
  end
end
