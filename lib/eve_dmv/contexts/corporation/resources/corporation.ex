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
          if(not is_nil(^arg(:min_rank)), do: activity_rank >= ^arg(:min_rank), else: true) and
            if(not is_nil(^arg(:max_rank)), do: activity_rank <= ^arg(:max_rank), else: true)
        )
      )
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
end
