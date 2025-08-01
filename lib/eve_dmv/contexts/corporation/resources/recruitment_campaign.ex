defmodule EveDmv.Contexts.Corporation.Resources.RecruitmentCampaign do
  @moduledoc """
  Recruitment campaign resource for tracking corporation recruitment efforts.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("recruitment_campaigns")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Campaign Basic Info
    attribute(:corporation_id, :integer, allow_nil?: false)
    attribute(:campaign_name, :string, allow_nil?: false)
    attribute(:description, :string)

    attribute(:status, :atom,
      constraints: [one_of: [:active, :paused, :completed, :cancelled]],
      default: :active
    )

    # Campaign Timeline
    attribute(:start_date, :utc_datetime, default: &DateTime.utc_now/0)
    attribute(:end_date, :utc_datetime)
    attribute(:target_recruits, :integer, default: 10)

    # Campaign Configuration
    attribute(:recruitment_channels, {:array, :string}, default: [])
    attribute(:requirements, :map, default: %{})
    attribute(:incentives, {:array, :string}, default: [])
    attribute(:responsible_recruiters, {:array, :string}, default: [])

    # Campaign Metrics
    attribute(:applications_received, :integer, default: 0)
    attribute(:applications_approved, :integer, default: 0)
    attribute(:applications_rejected, :integer, default: 0)
    attribute(:members_recruited, :integer, default: 0)

    # Performance Tracking
    attribute(:conversion_rate, :float, default: 0.0)
    attribute(:cost_per_recruit, :float, default: 0.0)
    attribute(:campaign_budget, :float)
    attribute(:budget_spent, :float, default: 0.0)

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
        :campaign_name,
        :description,
        :start_date,
        :end_date,
        :target_recruits,
        :recruitment_channels,
        :requirements,
        :incentives,
        :responsible_recruiters,
        :campaign_budget
      ])

      validate(present(:corporation_id))
      validate(present(:campaign_name))
    end

    update :update do
      primary?(true)

      accept([
        :campaign_name,
        :description,
        :status,
        :end_date,
        :target_recruits,
        :recruitment_channels,
        :requirements,
        :incentives,
        :responsible_recruiters,
        :applications_received,
        :applications_approved,
        :applications_rejected,
        :members_recruited,
        :conversion_rate,
        :cost_per_recruit,
        :campaign_budget,
        :budget_spent
      ])
    end

    update :update_metrics do
      accept([
        :applications_received,
        :applications_approved,
        :applications_rejected,
        :members_recruited,
        :conversion_rate,
        :cost_per_recruit,
        :budget_spent
      ])
    end

    read :by_corporation do
      argument(:corporation_id, :integer, allow_nil?: false)
      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :active_campaigns do
      filter(expr(status == :active))
    end

    read :by_status do
      argument(:status, :atom, allow_nil?: false)
      filter(expr(status == ^arg(:status)))
    end
  end

  calculations do
    calculate(
      :days_running,
      :integer,
      expr(fragment("EXTRACT(EPOCH FROM (? - ?)) / 86400", now(), start_date))
    )

    calculate(
      :success_rate,
      :float,
      expr(if applications_received > 0, do: applications_approved / applications_received, else: 0.0)
    )

    calculate(:is_active, :boolean, expr(status == :active))

    calculate(
      :budget_utilization,
      :float,
      expr(if campaign_budget > 0, do: budget_spent / campaign_budget, else: 0.0)
    )
  end

  validations do
    validate(present(:corporation_id))
    validate(present(:campaign_name))

    validate(numericality(:target_recruits, greater_than: 0))

    validate(numericality(:applications_received, greater_than_or_equal_to: 0))
  end
end
