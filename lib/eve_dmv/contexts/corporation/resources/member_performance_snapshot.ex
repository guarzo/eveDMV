defmodule EveDmv.Contexts.Corporation.Resources.MemberPerformanceSnapshot do
  @moduledoc """
  Member performance snapshot resource for tracking historical performance data.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("member_performance_snapshots")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Identifiers
    attribute(:character_id, :integer, allow_nil?: false)
    attribute(:corporation_id, :integer, allow_nil?: false)
    attribute(:snapshot_date, :date, allow_nil?: false)

    attribute(:snapshot_type, :atom,
      constraints: [one_of: [:daily, :weekly, :monthly]],
      default: :weekly
    )

    # Combat Performance
    attribute(:kills, :integer, default: 0)
    attribute(:losses, :integer, default: 0)
    attribute(:damage_dealt, :integer, default: 0)
    attribute(:isk_destroyed, :float, default: 0.0)
    attribute(:isk_lost, :float, default: 0.0)

    # Activity Metrics
    attribute(:activity_score, :float, default: 0.0)
    attribute(:login_days, :integer, default: 0)
    attribute(:fleet_participations, :integer, default: 0)
    attribute(:total_online_hours, :float, default: 0.0)

    # Performance Scores
    attribute(:combat_effectiveness, :float, default: 0.0)
    attribute(:fleet_contribution, :float, default: 0.0)
    attribute(:leadership_score, :float, default: 0.0)
    attribute(:overall_performance, :float, default: 0.0)

    # Rankings
    attribute(:corp_activity_rank, :integer)
    attribute(:corp_combat_rank, :integer)
    attribute(:corp_participation_rank, :integer)

    # Risk Indicators
    attribute(:flight_risk_score, :float, default: 0.0)

    attribute(:engagement_trend, :atom,
      constraints: [one_of: [:improving, :stable, :declining, :critical]],
      default: :stable
    )

    # Metadata
    create_timestamp(:created_at)
  end

  relationships do
    belongs_to :member, EveDmv.Contexts.Corporation.Resources.CorporationMember do
      source_attribute(:character_id)
      destination_attribute(:character_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :character_id,
        :corporation_id,
        :snapshot_date,
        :snapshot_type,
        :kills,
        :losses,
        :damage_dealt,
        :isk_destroyed,
        :isk_lost,
        :activity_score,
        :login_days,
        :fleet_participations,
        :total_online_hours,
        :combat_effectiveness,
        :fleet_contribution,
        :leadership_score,
        :overall_performance,
        :corp_activity_rank,
        :corp_combat_rank,
        :corp_participation_rank,
        :flight_risk_score,
        :engagement_trend
      ])

      validate(present(:character_id))
      validate(present(:corporation_id))
      validate(present(:snapshot_date))
    end

    update :update do
      primary?(true)

      accept([
        :kills,
        :losses,
        :damage_dealt,
        :isk_destroyed,
        :isk_lost,
        :activity_score,
        :login_days,
        :fleet_participations,
        :total_online_hours,
        :combat_effectiveness,
        :fleet_contribution,
        :leadership_score,
        :overall_performance,
        :corp_activity_rank,
        :corp_combat_rank,
        :corp_participation_rank,
        :flight_risk_score,
        :engagement_trend
      ])
    end

    read :by_character do
      argument(:character_id, :integer, allow_nil?: false)
      filter(expr(character_id == ^arg(:character_id)))
    end

    read :by_corporation do
      argument(:corporation_id, :integer, allow_nil?: false)
      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :by_date_range do
      argument(:start_date, :date, allow_nil?: false)
      argument(:end_date, :date, allow_nil?: false)

      filter(
        expr(
          snapshot_date >= ^arg(:start_date) and
            snapshot_date <= ^arg(:end_date)
        )
      )
    end

    read :top_performers do
      argument(:corporation_id, :integer, allow_nil?: false)
      argument(:metric, :atom, allow_nil?: true, default: :overall_performance)
      argument(:limit, :integer, allow_nil?: true, default: 10)

      filter(expr(corporation_id == ^arg(:corporation_id)))
      prepare(build(sort: [overall_performance: :desc]))
      # Note: limit would be applied in the calling code
    end

    read :recent_snapshots do
      argument(:character_id, :integer, allow_nil?: false)
      argument(:days, :integer, allow_nil?: true, default: 30)

      filter(
        expr(
          character_id == ^arg(:character_id) and
            snapshot_date >= ago(^arg(:days), :day)
        )
      )
    end
  end

  calculations do
    calculate(:kill_death_ratio, :float, expr(if losses > 0, do: kills / losses, else: kills))

    calculate(
      :isk_efficiency,
      :float,
      expr(if isk_lost > 0, do: isk_destroyed / (isk_destroyed + isk_lost), else: 1.0)
    )

    calculate(
      :days_ago,
      :integer,
      expr(fragment("EXTRACT(EPOCH FROM (? - ?)) / 86400", now(), snapshot_date))
    )

    calculate(:is_recent, :boolean, expr(snapshot_date >= ago(7, :day)))

    calculate(
      :performance_category,
      :atom,
      expr(
        cond do
          overall_performance >= 80 -> :excellent
          overall_performance >= 65 -> :good
          overall_performance >= 50 -> :average
          overall_performance >= 35 -> :below_average
          true -> :poor
        end
      )
    )
  end

  identities do
    identity(:unique_character_snapshot, [:character_id, :snapshot_date, :snapshot_type])
  end

  validations do
    validate(present(:character_id))
    validate(present(:corporation_id))
    validate(present(:snapshot_date))

    validate(numericality(:kills, greater_than_or_equal_to: 0))

    validate(numericality(:losses, greater_than_or_equal_to: 0))

    validate(
      numericality(:activity_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0)
    )

    validate(
      numericality(:overall_performance,
        greater_than_or_equal_to: 0.0,
        less_than_or_equal_to: 100.0
      )
    )
  end

  code_interface do
    domain(EveDmv.Api)
    define(:create)
    define(:update)
    define(:read)
    define(:destroy)
    define(:list_by_character, action: :by_character, args: [:character_id])
    define(:list_by_corporation, action: :by_corporation, args: [:corporation_id])
    define(:list_by_date_range, action: :by_date_range, args: [:start_date, :end_date])

    define(:list_top_performers,
      action: :top_performers,
      args: [:corporation_id, :metric, :limit]
    )

    define(:list_recent_snapshots, action: :recent_snapshots, args: [:character_id, :days])
  end
end
