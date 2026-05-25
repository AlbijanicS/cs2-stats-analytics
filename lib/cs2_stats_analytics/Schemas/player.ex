defmodule Cs2StatsAnalytics.Schemas.Player do
  @moduledoc """
  Ecto schema for a FACEIT player tracked by the application.

  Players are identified by the stable FACEIT player id and can have many
  imported match stat rows through `PlayerMatchStat`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "players" do
    field :faceit_player_id, :string
    field :nickname, :string
    field :steam_id, :string
    field :avatar_url, :string
    field :country, :string
    field :skill_level, :integer
    field :faceit_elo, :integer
    field :last_synced_at, :utc_datetime

    has_many :player_match_stats, Cs2StatsAnalytics.Schemas.PlayerMatchStat

    has_many :matches,
      through: [:player_match_stats, :match]

    timestamps(type: :utc_datetime)
  end

  def changeset(player, attrs) do
    player
    |> cast(attrs, [
      :faceit_player_id,
      :nickname,
      :steam_id,
      :avatar_url,
      :country,
      :skill_level,
      :faceit_elo,
      :last_synced_at
    ])
    |> validate_required([:faceit_player_id, :nickname])
    |> unique_constraint(:faceit_player_id)
  end
end
