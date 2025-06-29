defmodule EveDmv.Surveillance.ProfileMatch do
  @moduledoc """
  Record of a surveillance profile matching a killmail.

  This resource tracks when profiles successfully match killmails,
  providing an audit trail and enabling performance analytics.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("surveillance_profile_matches")
    repo(EveDmv.Repo)

    custom_indexes do
      index([:profile_id], name: "profile_matches_profile_idx")
      index([:killmail_id, :killmail_time], name: "profile_matches_killmail_idx")
      index([:matched_at], name: "profile_matches_time_idx")
      index([:profile_id, :matched_at], name: "profile_matches_profile_time_idx")
    end
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api)
    define(:read, action: :read)
    define(:create, action: :create)
    define(:recent_matches, args: [:hours])
    define(:profile_matches, args: [:profile_id])
  end

  # Attributes
  attributes do
    # Primary key
    uuid_primary_key(:id)

    # Profile reference
    attribute :profile_id, :uuid do
      allow_nil?(false)
      description("ID of the profile that matched")
    end

    # Killmail reference (composite to match killmail tables)
    attribute :killmail_id, :integer do
      allow_nil?(false)
      description("EVE killmail ID")
    end

    attribute :killmail_time, :utc_datetime do
      allow_nil?(false)
      description("When the kill occurred")
    end

    # Matching metadata
    attribute :matched_at, :utc_datetime do
      allow_nil?(false)
      default(&DateTime.utc_now/0)
      description("When the profile matched this killmail")
    end

    attribute :match_conditions, :map do
      allow_nil?(true)
      description("JSON object describing which conditions matched")
    end

    # Killmail summary for quick access
    attribute :victim_character_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Victim character name for display")
    end

    attribute :victim_ship_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Victim ship name for display")
    end

    attribute :solar_system_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Solar system name for display")
    end

    attribute :total_value, :decimal do
      allow_nil?(true)
      constraints(precision: 15, scale: 2)
      description("Total ISK value of the kill")
    end

    # Automatic timestamps
    timestamps()
  end

  # Relationships
  relationships do
    belongs_to :profile, EveDmv.Surveillance.Profile do
      destination_attribute(:id)
      source_attribute(:profile_id)
      description("The profile that generated this match")
    end

    # Note: Relationship to killmail will be added when we improve foreign keys
  end

  # Actions
  actions do
    # Default actions
    defaults([:read, :destroy])

    # Custom create action
    create :create do
      primary?(true)
      description("Record a profile match")

      accept([
        :profile_id,
        :killmail_id,
        :killmail_time,
        :match_conditions,
        :victim_character_name,
        :victim_ship_name,
        :solar_system_name,
        :total_value
      ])

      validate(present(:profile_id))
      validate(present(:killmail_id))
      validate(present(:killmail_time))
    end

    # Read actions
    read :recent_matches do
      description("Get recent profile matches")

      argument :hours, :integer do
        allow_nil?(false)
        default(24)
        description("Number of hours to look back")
      end

      filter(expr(matched_at >= ago(^arg(:hours), :hour)))
      prepare(build(sort: [matched_at: :desc]))
    end

    read :profile_matches do
      description("Get matches for a specific profile")

      argument :profile_id, :uuid do
        allow_nil?(false)
        description("Profile ID to filter by")
      end

      filter(expr(profile_id == ^arg(:profile_id)))
      prepare(build(sort: [matched_at: :desc]))
      # Limit to last 100 matches
      prepare(build(limit: 100))
    end
  end

  # Note: Aggregates removed for now - will be added with specific relationship queries

  # Calculations
  calculations do
    calculate :age_minutes, :integer, expr(datetime_diff(now(), matched_at, :minute)) do
      description("How many minutes ago this match occurred")
    end

    calculate :is_recent, :boolean, expr(matched_at > ago(1, :hour)) do
      description("Whether this match occurred in the last hour")
    end
  end

  # Authorization policies
  policies do
    # Users can only read matches for their own profiles
    policy action_type(:read) do
      authorize_if(expr(profile.user_id == ^actor(:id)))
    end

    # System can create matches for any profile
    policy action_type([:create, :update, :destroy]) do
      authorize_if(actor_attribute_equals(:role, "system"))
    end

    # Admin users can access all matches
    policy action_type([:read, :create, :update, :destroy]) do
      authorize_if(actor_attribute_equals(:role, "admin"))
    end
  end
end
