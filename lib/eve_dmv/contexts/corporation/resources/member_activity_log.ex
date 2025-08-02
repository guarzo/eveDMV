defmodule EveDmv.Contexts.Corporation.Resources.MemberActivityLog do
  @moduledoc """
  Member activity log resource for tracking individual member activities and events.
  """
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("member_activity_logs")
    repo(EveDmv.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Identifiers
    attribute(:character_id, :integer, allow_nil?: false)
    attribute(:corporation_id, :integer, allow_nil?: false)
    attribute(:activity_date, :utc_datetime, allow_nil?: false)

    # Activity Details
    attribute(:activity_type, :atom,
      constraints: [
        one_of: [
          :login,
          :logout,
          :fleet_join,
          :fleet_leave,
          :kill,
          :loss,
          :role_change,
          :location_change
        ]
      ],
      allow_nil?: false
    )

    attribute(:activity_description, :string)
    attribute(:activity_data, :map, default: %{})

    # Context Information
    attribute(:system_id, :integer)
    attribute(:system_name, :string)
    attribute(:ship_type_id, :integer)
    attribute(:ship_type_name, :string)

    # Metrics
    attribute(:activity_score_impact, :float, default: 0.0)
    attribute(:duration_minutes, :integer)

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
        :activity_date,
        :activity_type,
        :activity_description,
        :activity_data,
        :system_id,
        :system_name,
        :ship_type_id,
        :ship_type_name,
        :activity_score_impact,
        :duration_minutes
      ])

      validate(present(:character_id))
      validate(present(:corporation_id))
      validate(present(:activity_date))
      validate(present(:activity_type))
    end

    read :by_character do
      argument(:character_id, :integer, allow_nil?: false)
      filter(expr(character_id == ^arg(:character_id)))
    end

    read :by_corporation do
      argument(:corporation_id, :integer, allow_nil?: false)
      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :by_activity_type do
      argument(:activity_type, :atom, allow_nil?: false)
      filter(expr(activity_type == ^arg(:activity_type)))
    end

    read :by_date_range do
      argument(:start_date, :utc_datetime, allow_nil?: false)
      argument(:end_date, :utc_datetime, allow_nil?: false)

      filter(
        expr(
          activity_date >= ^arg(:start_date) and
            activity_date <= ^arg(:end_date)
        )
      )
    end

    read :recent_activity do
      argument(:character_id, :integer, allow_nil?: false)
      argument(:days, :integer, allow_nil?: true, default: 7)

      filter(
        expr(
          character_id == ^arg(:character_id) and
            activity_date >= ago(^arg(:days), :day)
        )
      )
    end
  end

  calculations do
    calculate(
      :days_ago,
      :integer,
      expr(fragment("EXTRACT(EPOCH FROM (? - ?)) / 86400", now(), activity_date))
    )

    calculate(:is_recent, :boolean, expr(activity_date >= ago(7, :day)))

    calculate(:is_combat_activity, :boolean, expr(activity_type in [:kill, :loss]))

    calculate(:is_fleet_activity, :boolean, expr(activity_type in [:fleet_join, :fleet_leave]))
  end

  validations do
    validate(present(:character_id))
    validate(present(:corporation_id))
    validate(present(:activity_date))
    validate(present(:activity_type))

    validate(numericality(:duration_minutes, greater_than_or_equal_to: 0))
  end
end
