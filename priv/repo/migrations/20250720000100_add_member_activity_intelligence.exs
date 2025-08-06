defmodule EveDmv.Repo.Migrations.AddMemberActivityIntelligence do
  @moduledoc """
  Add member_activity_intelligence table for wormhole operations analysis.
  """

  use Ecto.Migration

  def up do
    create table(:member_activity_intelligence, primary_key: false) do
      add(:id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true)
      add(:character_id, :bigint, null: false)
      add(:character_name, :text, null: false)
      add(:corporation_id, :bigint, null: false)
      add(:corporation_name, :text, null: false)
      add(:alliance_id, :bigint)
      add(:alliance_name, :text)
      add(:activity_period_start, :utc_datetime, null: false)
      add(:activity_period_end, :utc_datetime, null: false)
      add(:analysis_generated_at, :utc_datetime, default: fragment("(now() AT TIME ZONE 'utc')"))
      add(:total_pvp_kills, :bigint, default: 0)
      add(:total_pvp_losses, :bigint, default: 0)
      add(:home_defense_participations, :bigint, default: 0)
      add(:chain_operations_participations, :bigint, default: 0)
      add(:fleet_participations, :bigint, default: 0)
      add(:solo_activities, :bigint, default: 0)
      add(:engagement_score, :float, default: 0.0)
      add(:activity_trend, :text, default: "stable")
      add(:burnout_risk_score, :bigint, default: 0)
      add(:disengagement_risk_score, :bigint, default: 0)
      add(:activity_patterns, :map, default: %{})
      add(:participation_metrics, :map, default: %{})
      add(:warning_indicators, :map, default: %{})
      add(:timezone_analysis, :map, default: %{})
      add(:corp_percentile_ranking, :bigint, default: 50)
      add(:peer_comparison_score, :float, default: 0.0)

      add(:inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )

      add(:updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
      )
    end

    # Indexes for common queries
    create index(:member_activity_intelligence, [:character_id])
    create index(:member_activity_intelligence, [:corporation_id])
    create index(:member_activity_intelligence, [:alliance_id])
    create index(:member_activity_intelligence, [:activity_period_end])
    create index(:member_activity_intelligence, [:engagement_score])
  end

  def down do
    drop table(:member_activity_intelligence)
  end
end