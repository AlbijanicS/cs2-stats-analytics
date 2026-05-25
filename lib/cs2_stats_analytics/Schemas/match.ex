defmodule Cs2StatsAnalytics.Schemas.Match do
  @moduledoc """
  Ecto schema for an imported CS2 match.

  Matches are identified by FACEIT match id and store basic match metadata plus
  the raw source payload used for traceability while the app is still evolving.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "matches" do
    field :faceit_match_id, :string
    field :game, :string
    field :map, :string
    field :started_at, :utc_datetime
    field :finished_at, :utc_datetime
    field :winner, :string
    field :score_faction1, :integer
    field :score_faction2, :integer
    field :raw_payload, :map

    has_many :player_match_stats, Cs2StatsAnalytics.Schemas.PlayerMatchStat

    has_many :players,
      through: [:player_match_stats, :player]

    timestamps(type: :utc_datetime)
  end

  def changeset(match, attrs) do
    match
    |> cast(attrs, [
      :faceit_match_id,
      :game,
      :map,
      :started_at,
      :finished_at,
      :winner,
      :score_faction1,
      :score_faction2,
      :raw_payload
    ])
    |> validate_required([:faceit_match_id, :game])
    |> unique_constraint(:faceit_match_id)
  end
end
