defmodule Cs2StatsAnalytics.PlayerMatchImporter do
  @moduledoc """
  Persists a normalized player, match, and stat line in one transaction.

  The importer expects already-normalized attrs. It does not call external
  services or perform dashboard calculations. Upserts use explicit replace
  field lists so imports can be rerun safely without blindly replacing every
  database column.
  """

  alias Ecto.Multi
  alias Cs2StatsAnalytics.Repo
  alias Cs2StatsAnalytics.Schemas.{Player, Match, PlayerMatchStat}

  @player_replace_fields [
    :nickname,
    :steam_id,
    :avatar_url,
    :country,
    :skill_level,
    :faceit_elo,
    :last_synced_at,
    :updated_at
  ]

  @match_replace_fields [
    :game,
    :map,
    :started_at,
    :finished_at,
    :winner,
    :score_faction1,
    :score_faction2,
    :raw_payload,
    :updated_at
  ]

  @stat_replace_fields [
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
    :updated_at
  ]

  def import_player_match(%{player: player_attrs, match: match_attrs, stats: stats_attrs}) do
    Multi.new()
    |> Multi.insert(:player, Player.changeset(%Player{}, player_attrs),
      on_conflict: {:replace, @player_replace_fields},
      conflict_target: :faceit_player_id,
      returning: true
    )
    |> Multi.insert(:match, Match.changeset(%Match{}, match_attrs),
      on_conflict: {:replace, @match_replace_fields},
      conflict_target: :faceit_match_id,
      returning: true
    )
    |> Multi.run(:player_match_stat, fn repo, %{player: player, match: match} ->
      stats_attrs =
        Map.merge(stats_attrs, %{
          player_id: player.id,
          match_id: match.id
        })

      repo.insert(PlayerMatchStat.changeset(%PlayerMatchStat{}, stats_attrs),
        on_conflict: {:replace, @stat_replace_fields},
        conflict_target: [:player_id, :match_id],
        returning: true
      )
    end)
    |> Repo.transaction()
  end
end
