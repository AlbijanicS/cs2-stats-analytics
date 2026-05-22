defmodule Cs2StatsAnalytics.Schemas.PlayerMatchStat do
  use Ecto.Schema
  import Ecto.Changeset

  alias Cs2StatsAnalytics.Schemas.{Player, Match}

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

    timestamps(type: :utc_datetime)
  end

  def changeset(player_match_stat, attrs) do
    player_match_stat
    |> cast(attrs, [
      :player_id,
      :match_id,
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
      :raw_stats
    ])
    |> validate_required([:player_id, :match_id])
    |> foreign_key_constraint(:player_id)
    |> foreign_key_constraint(:match_id)
    |> unique_constraint([:player_id, :match_id])
  end
end
