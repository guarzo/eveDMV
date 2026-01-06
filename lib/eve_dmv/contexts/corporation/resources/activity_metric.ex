defmodule EveDmv.Contexts.Corporation.Resources.ActivityMetric do
  @moduledoc """
  Corporation activity metrics resource for tracking organizational performance over time.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("corporation_activity_metrics")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Identifiers
    attribute(:corporation_id, :integer, allow_nil?: false)
    attribute(:metric_date, :date, allow_nil?: false)

    attribute(:metric_type, :atom,
      constraints: [one_of: [:daily, :weekly, :monthly]],
      default: :daily
    )

    # Member Metrics
    attribute(:total_members, :integer, default: 0)
    attribute(:active_members, :integer, default: 0)
    attribute(:new_members, :integer, default: 0)
    attribute(:departed_members, :integer, default: 0)

    # Activity Metrics
    attribute(:avg_activity_score, :float, default: 0.0)
    attribute(:total_logins, :integer, default: 0)
    attribute(:fleet_participation_events, :integer, default: 0)
    attribute(:unique_participants, :integer, default: 0)

    # Performance Metrics
    attribute(:total_kills, :integer, default: 0)
    attribute(:total_losses, :integer, default: 0)
    attribute(:isk_destroyed, :float, default: 0.0)
    attribute(:isk_lost, :float, default: 0.0)
    attribute(:damage_dealt, :integer, default: 0)

    # Organizational Health
    attribute(:leadership_activity_score, :float, default: 0.0)
    attribute(:member_retention_rate, :float, default: 0.0)
    attribute(:recruitment_velocity, :float, default: 0.0)
    attribute(:flight_risk_count, :integer, default: 0)

    # Metadata
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :corporation, EveDmv.Contexts.Corporation.Resources.Corporation do
      source_attribute(:corporation_id)
      destination_attribute(:corporation_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :corporation_id,
        :metric_date,
        :metric_type,
        :total_members,
        :active_members,
        :new_members,
        :departed_members,
        :avg_activity_score,
        :total_logins,
        :fleet_participation_events,
        :unique_participants,
        :total_kills,
        :total_losses,
        :isk_destroyed,
        :isk_lost,
        :damage_dealt,
        :leadership_activity_score,
        :member_retention_rate,
        :recruitment_velocity,
        :flight_risk_count
      ])

      validate(present(:corporation_id))
      validate(present(:metric_date))
    end

    update :update do
      primary?(true)

      accept([
        :total_members,
        :active_members,
        :new_members,
        :departed_members,
        :avg_activity_score,
        :total_logins,
        :fleet_participation_events,
        :unique_participants,
        :total_kills,
        :total_losses,
        :isk_destroyed,
        :isk_lost,
        :damage_dealt,
        :leadership_activity_score,
        :member_retention_rate,
        :recruitment_velocity,
        :flight_risk_count
      ])
    end

    read :by_corporation do
      argument(:corporation_id, :integer, allow_nil?: false)
      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :by_date_range do
      argument(:corporation_id, :integer, allow_nil?: false)
      argument(:start_date, :date, allow_nil?: false)
      argument(:end_date, :date, allow_nil?: false)

      filter(
        expr(
          corporation_id == ^arg(:corporation_id) and
            metric_date >= ^arg(:start_date) and
            metric_date <= ^arg(:end_date)
        )
      )
    end

    read :by_metric_type do
      argument(:metric_type, :atom, allow_nil?: false)
      filter(expr(metric_type == ^arg(:metric_type)))
    end

    read :recent_metrics do
      argument(:corporation_id, :integer, allow_nil?: false)
      argument(:days, :integer, allow_nil?: true, default: 30)

      filter(
        expr(
          corporation_id == ^arg(:corporation_id) and
            metric_date >= ago(^arg(:days), :day)
        )
      )
    end
  end

  calculations do
    calculate(
      :kill_death_ratio,
      :float,
      expr(if total_losses > 0, do: total_kills / total_losses, else: total_kills)
    )

    calculate(
      :isk_efficiency,
      :float,
      expr(if isk_lost > 0, do: isk_destroyed / (isk_destroyed + isk_lost), else: 1.0)
    )

    calculate(
      :participation_rate,
      :float,
      expr(if total_members > 0, do: unique_participants / total_members, else: 0.0)
    )

    calculate(
      :member_growth_rate,
      :float,
      expr(if total_members > 0, do: (new_members - departed_members) / total_members, else: 0.0)
    )
  end

  identities do
    identity(:unique_corp_metric, [:corporation_id, :metric_date, :metric_type])
  end

  validations do
    validate(present(:corporation_id))
    validate(present(:metric_date))

    validate(numericality(:total_members, greater_than_or_equal_to: 0))

    validate(numericality(:active_members, greater_than_or_equal_to: 0))

    validate(
      numericality(:avg_activity_score,
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
    define(:list_by_corporation, action: :by_corporation, args: [:corporation_id])

    define(:list_by_date_range,
      action: :by_date_range,
      args: [:corporation_id, :start_date, :end_date]
    )

    define(:list_by_metric_type, action: :by_metric_type, args: [:metric_type])
    define(:list_recent_metrics, action: :recent_metrics, args: [:corporation_id, :days])
  end
end
