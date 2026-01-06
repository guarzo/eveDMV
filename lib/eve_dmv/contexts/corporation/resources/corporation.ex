defmodule EveDmv.Contexts.Corporation.Resources.Corporation do
  @moduledoc """
  Corporation resource definition using Ash Framework.

  Represents corporation entities with comprehensive data management
  for membership, analytics, and operational data.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("corporations")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Core Corporation Data
    attribute(:corporation_id, :integer, allow_nil?: false)
    attribute(:corporation_name, :string, allow_nil?: false)
    attribute(:ticker, :string)
    attribute(:alliance_id, :integer)
    attribute(:alliance_name, :string)
    attribute(:ceo_id, :integer)
    attribute(:ceo_name, :string)

    # Organizational Data
    attribute(:founded_date, :utc_datetime)
    attribute(:headquarters_system_id, :integer)
    attribute(:headquarters_system_name, :string)
    attribute(:member_count, :integer, default: 0)
    attribute(:tax_rate, :float)

    # Status and Configuration
    attribute(:recruitment_status, :atom,
      constraints: [one_of: [:open, :selective, :closed]],
      default: :selective
    )

    attribute(:war_eligible, :boolean, default: true)
    attribute(:public_info, :map, default: %{})

    # Activity Metrics (cached/computed)
    attribute(:avg_activity_score, :float)
    attribute(:last_activity_update, :utc_datetime)
    attribute(:activity_rank, :integer)

    # Analytics Cache
    attribute(:cached_analytics, :map, default: %{})
    attribute(:analytics_updated_at, :utc_datetime)

    # Metadata
    create_timestamp(:created_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :members, EveDmv.Contexts.Corporation.Resources.CorporationMember do
      destination_attribute(:corporation_id)
      source_attribute(:corporation_id)
    end

    has_many :recruitment_campaigns, EveDmv.Contexts.Corporation.Resources.RecruitmentCampaign do
      destination_attribute(:corporation_id)
      source_attribute(:corporation_id)
    end

    has_many :activity_metrics, EveDmv.Contexts.Corporation.Resources.ActivityMetric do
      destination_attribute(:corporation_id)
      source_attribute(:corporation_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :corporation_id,
        :corporation_name,
        :ticker,
        :alliance_id,
        :alliance_name,
        :ceo_id,
        :ceo_name,
        :founded_date,
        :headquarters_system_id,
        :headquarters_system_name,
        :member_count,
        :tax_rate,
        :recruitment_status,
        :war_eligible,
        :public_info
      ])

      validate(present(:corporation_id))
      validate(present(:corporation_name))
    end

    update :update do
      primary?(true)

      accept([
        :corporation_name,
        :ticker,
        :alliance_id,
        :alliance_name,
        :ceo_id,
        :ceo_name,
        :headquarters_system_id,
        :headquarters_system_name,
        :member_count,
        :tax_rate,
        :recruitment_status,
        :war_eligible,
        :public_info,
        :avg_activity_score,
        :last_activity_update,
        :activity_rank,
        :cached_analytics,
        :analytics_updated_at
      ])
    end

    update :update_activity_metrics do
      accept([:avg_activity_score, :last_activity_update, :activity_rank])
    end

    update :update_cached_analytics do
      accept([:cached_analytics, :analytics_updated_at])
    end

    read :by_corporation_id do
      argument(:corporation_id, :integer, allow_nil?: false)
      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :by_alliance do
      argument(:alliance_id, :integer, allow_nil?: false)
      filter(expr(alliance_id == ^arg(:alliance_id)))
    end

    read :active_recruitment do
      filter(expr(recruitment_status in [:open, :selective]))
    end

    read :by_activity_rank do
      argument(:min_rank, :integer, allow_nil?: true)
      argument(:max_rank, :integer, allow_nil?: true)

      filter(
        expr(
          (is_nil(^arg(:min_rank)) or activity_rank >= ^arg(:min_rank)) and
            (is_nil(^arg(:max_rank)) or activity_rank <= ^arg(:max_rank))
        )
      )
    end
  end

  aggregates do
    count :total_member_count, :members do
      description("Total number of corporation members tracked in the system")
    end

    count :active_members_count, :members do
      description("Members who have been seen in the last 30 days")
      filter(expr(last_seen >= ago(30, :day)))
    end

    count :pvp_active_members_count, :members do
      description("Members with at least one kill tracked")
      filter(expr(total_kills > 0))
    end

    sum :total_corp_kills, :members, :total_kills do
      description("Sum of all kills across all members")
    end

    sum :total_corp_losses, :members, :total_losses do
      description("Sum of all losses across all members")
    end

    sum :total_corp_isk_destroyed, :members, :isk_destroyed do
      description("Total ISK destroyed by all members")
    end

    first :top_killer_character_id, :members, :character_id do
      description("Character ID of the member with most kills")
      sort([{:total_kills, :desc}])
    end

    first :top_killer_name, :members, :character_name do
      description("Name of the member with most kills")
      sort([{:total_kills, :desc}])
    end
  end

  calculations do
    calculate(:member_activity_score, :float, expr(avg_activity_score || 0.0))

    calculate(:is_recruiting, :boolean, expr(recruitment_status in [:open, :selective]))

    calculate(
      :days_since_founded,
      :integer,
      expr(fragment("EXTRACT(EPOCH FROM (? - ?)) / 86400", now(), founded_date))
    )

    calculate(
      :analytics_age_hours,
      :integer,
      expr(fragment("EXTRACT(EPOCH FROM (? - ?)) / 3600", now(), analytics_updated_at))
    )

    calculate :corp_kill_death_ratio, :float do
      description("Corporation-wide kill/death ratio from tracked members")

      calculation(fn records, _context ->
        Enum.map(records, fn corp ->
          kills = corp.total_corp_kills || 0
          losses = corp.total_corp_losses || 0

          if losses > 0, do: Float.round(kills / losses, 2), else: kills * 1.0
        end)
      end)
    end
  end

  identities do
    identity(:unique_corporation_id, [:corporation_id])
  end

  validations do
    validate(present(:corporation_id))
    validate(present(:corporation_name))

    validate(match(:ticker, ~r/^[A-Z0-9]{3,5}$/))

    validate(numericality(:member_count, greater_than_or_equal_to: 0))

    validate(numericality(:tax_rate, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 100.0))
  end

  code_interface do
    domain(EveDmv.Api)
    define(:create)
    define(:update)
    define(:read)
    define(:destroy)
    define(:get_by_corporation_id, action: :by_corporation_id, args: [:corporation_id])
    define(:list_by_alliance, action: :by_alliance, args: [:alliance_id])
    define(:list_active_recruitment, action: :active_recruitment)
    define(:list_by_activity_rank, action: :by_activity_rank, args: [:min_rank, :max_rank])
    define(:update_activity_metrics)
    define(:update_cached_analytics)
  end
end
