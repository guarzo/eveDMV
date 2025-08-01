defmodule EveDmv.Contexts.Corporation.Resources.CorporationMember do
  @moduledoc """
  Corporation member resource definition using Ash Framework.

  Represents individual members within corporations with activity tracking,
  role management, and analytics data.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("corporation_members")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Identifiers
    attribute(:corporation_id, :integer, allow_nil?: false)
    attribute(:character_id, :integer, allow_nil?: false)
    attribute(:character_name, :string, allow_nil?: false)

    # Member Status
    attribute(:join_date, :utc_datetime, default: &DateTime.utc_now/0)
    attribute(:last_seen, :utc_datetime)

    attribute(:status, :atom,
      constraints: [one_of: [:active, :inactive, :on_leave, :probation]],
      default: :active
    )

    # Roles and Permissions
    attribute(:roles, {:array, :string}, default: [])
    attribute(:title, :string)
    attribute(:base_id, :integer)
    attribute(:location_id, :integer)

    # Activity Metrics
    attribute(:recent_activity_score, :float, default: 0.0)
    attribute(:total_login_days, :integer, default: 0)
    attribute(:fleet_participation_count, :integer, default: 0)
    attribute(:last_fleet_participation, :utc_datetime)

    # Performance Data
    attribute(:total_kills, :integer, default: 0)
    attribute(:total_losses, :integer, default: 0)
    attribute(:total_damage_dealt, :integer, default: 0)
    attribute(:isk_destroyed, :float, default: 0.0)
    attribute(:isk_lost, :float, default: 0.0)

    # Risk Assessment
    attribute(:flight_risk_score, :float, default: 0.0)
    attribute(:integration_score, :float, default: 0.0)

    attribute(:retention_risk, :atom,
      constraints: [one_of: [:low, :medium, :high, :critical]],
      default: :low
    )

    # Member Notes and Tracking
    attribute(:notes, :string)
    attribute(:recruiter_id, :integer)
    attribute(:mentor_id, :integer)
    attribute(:probation_end_date, :utc_datetime)

    # Analytics Cache
    attribute(:cached_stats, :map, default: %{})
    attribute(:stats_updated_at, :utc_datetime)

    # Metadata
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :corporation, EveDmv.Contexts.Corporation.Resources.Corporation do
      source_attribute(:corporation_id)
      destination_attribute(:corporation_id)
    end

    has_many :activity_logs, EveDmv.Contexts.Corporation.Resources.MemberActivityLog do
      destination_attribute(:character_id)
      source_attribute(:character_id)
    end

    has_many :performance_snapshots,
             EveDmv.Contexts.Corporation.Resources.MemberPerformanceSnapshot do
      destination_attribute(:character_id)
      source_attribute(:character_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :corporation_id,
        :character_id,
        :character_name,
        :join_date,
        :status,
        :roles,
        :title,
        :base_id,
        :location_id,
        :notes,
        :recruiter_id,
        :mentor_id
      ])

      validate(present(:corporation_id))
      validate(present(:character_id))
      validate(present(:character_name))
    end

    update :update do
      primary?(true)

      accept([
        :character_name,
        :last_seen,
        :status,
        :roles,
        :title,
        :base_id,
        :location_id,
        :recent_activity_score,
        :total_login_days,
        :fleet_participation_count,
        :last_fleet_participation,
        :total_kills,
        :total_losses,
        :total_damage_dealt,
        :isk_destroyed,
        :isk_lost,
        :flight_risk_score,
        :integration_score,
        :retention_risk,
        :notes,
        :mentor_id,
        :probation_end_date,
        :cached_stats,
        :stats_updated_at
      ])
    end

    update :update_activity do
      accept([
        :last_seen,
        :recent_activity_score,
        :total_login_days,
        :fleet_participation_count,
        :last_fleet_participation
      ])
    end

    update :update_performance do
      accept([
        :total_kills,
        :total_losses,
        :total_damage_dealt,
        :isk_destroyed,
        :isk_lost
      ])
    end

    update :update_risk_assessment do
      accept([:flight_risk_score, :integration_score, :retention_risk])
    end

    update :assign_roles do
      accept([:roles])
    end

    read :by_corporation do
      argument(:corporation_id, :integer, allow_nil?: false)
      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :by_character do
      argument(:character_id, :integer, allow_nil?: false)
      filter(expr(character_id == ^arg(:character_id)))
    end

    read :active_members do
      filter(expr(status == :active))
    end

    read :by_role do
      argument(:role, :string, allow_nil?: false)
      filter(expr(^arg(:role) in roles))
    end

    read :high_activity do
      argument(:min_score, :float, allow_nil?: true, default: 70.0)
      filter(expr(recent_activity_score >= ^arg(:min_score)))
    end

    read :flight_risks do
      argument(:min_risk_score, :float, allow_nil?: true, default: 70.0)
      filter(expr(flight_risk_score >= ^arg(:min_risk_score)))
    end

    read :new_members do
      argument(:days, :integer, allow_nil?: true, default: 30)
      filter(expr(join_date >= ago(^arg(:days), :day)))
    end

    read :inactive_members do
      argument(:days, :integer, allow_nil?: true, default: 30)
      filter(expr(last_seen <= ago(^arg(:days), :day)))
    end
  end

  calculations do
    calculate(
      :tenure_days,
      :integer,
      expr(fragment("EXTRACT(EPOCH FROM (? - ?)) / 86400", now(), join_date))
    )

    calculate(
      :days_since_last_seen,
      :integer,
      expr(fragment("EXTRACT(EPOCH FROM (? - ?)) / 86400", now(), last_seen))
    )

    calculate(
      :kill_death_ratio,
      :float,
      expr(if(total_losses > 0, total_kills / total_losses, total_kills))
    )

    calculate(
      :isk_efficiency,
      :float,
      expr(if(isk_lost > 0, isk_destroyed / (isk_destroyed + isk_lost), 1.0))
    )

    calculate(
      :is_leadership,
      :boolean,
      expr("CEO" in roles or "Director" in roles or "Personnel Manager" in roles)
    )

    calculate(
      :activity_status,
      :atom,
      expr(
        cond do
          recent_activity_score >= 80 -> :very_active
          recent_activity_score >= 60 -> :active
          recent_activity_score >= 40 -> :moderate
          recent_activity_score >= 20 -> :low
          true -> :inactive
        end
      )
    )

    calculate(:is_new_member, :boolean, expr(join_date >= ago(90, :day)))

    calculate(:is_veteran, :boolean, expr(join_date <= ago(365, :day)))
  end

  identities do
    identity(:unique_corp_character, [:corporation_id, :character_id])
  end

  validations do
    validate(present(:corporation_id))
    validate(present(:character_id))
    validate(present(:character_name))

    validate(
      numericality(:recent_activity_score,
        greater_than_or_equal_to: 0.0,
        less_than_or_equal_to: 100.0
      )
    )

    validate(
      numericality(:flight_risk_score,
        greater_than_or_equal_to: 0.0,
        less_than_or_equal_to: 100.0
      )
    )

    validate(
      numericality(:integration_score,
        greater_than_or_equal_to: 0.0,
        less_than_or_equal_to: 100.0
      )
    )

    validate(numericality(:total_kills, greater_than_or_equal_to: 0))

    validate(numericality(:total_losses, greater_than_or_equal_to: 0))
  end
end
