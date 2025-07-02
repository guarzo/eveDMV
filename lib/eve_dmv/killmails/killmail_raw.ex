defmodule EveDmv.Killmails.KillmailRaw do
  @moduledoc """
  Raw killmail data resource from wanderer-kills/zKillboard.

  This resource stores the unprocessed killmail data as received from external
  sources, partitioned by killmail_time for optimal performance.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("killmails_raw")
    repo(EveDmv.Repo)
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api)
  end

  # Attributes
  attributes do
    # Composite primary key for partitioned table
    attribute :killmail_id, :integer do
      allow_nil?(false)
      primary_key?(true)
      description("Unique EVE killmail ID")
    end

    attribute :killmail_time, :utc_datetime do
      allow_nil?(false)
      primary_key?(true)
      description("When the kill occurred (partition key)")
    end

    attribute :killmail_hash, :string do
      allow_nil?(false)
      constraints(max_length: 255)
      description("Unique hash for the killmail")
    end

    # Location information
    attribute :solar_system_id, :integer do
      allow_nil?(false)
      description("EVE solar system ID where kill occurred")
    end

    # Victim information
    attribute :victim_character_id, :integer do
      allow_nil?(true)
      description("Victim character ID")
    end

    attribute :victim_corporation_id, :integer do
      allow_nil?(true)
      description("Victim corporation ID")
    end

    attribute :victim_alliance_id, :integer do
      allow_nil?(true)
      description("Victim alliance ID")
    end

    attribute :victim_ship_type_id, :integer do
      allow_nil?(false)
      description("Type ID of the ship that was killed")
    end

    # Kill metadata
    attribute :attacker_count, :integer do
      allow_nil?(false)
      default(0)
      constraints(min: 0)
      description("Number of attackers on the killmail")
    end

    # Raw data storage
    attribute :raw_data, :map do
      allow_nil?(false)
      description("Complete raw killmail data as JSON")
    end

    attribute :source, :string do
      allow_nil?(false)
      default("wanderer-kills")
      constraints(max_length: 50)
      description("Source of the killmail data (wanderer-kills, zkillboard, etc.)")
    end

    # Automatic timestamp
    create_timestamp(:inserted_at)
  end

  # Identities for uniqueness
  identities do
    identity :unique_killmail, [:killmail_id, :killmail_time] do
      description("Each killmail ID + time combination is unique")
    end

    identity :unique_hash_time, [:killmail_hash, :killmail_time] do
      description("Each killmail hash + time combination is unique")
    end
  end

  # Actions
  actions do
    # Default actions
    defaults([:read])

    # Default create action accepting all attributes
    create :create do
      primary?(true)
      description("Create a raw killmail record")

      accept([
        :killmail_id,
        :killmail_hash,
        :killmail_time,
        :solar_system_id,
        :victim_character_id,
        :victim_corporation_id,
        :victim_alliance_id,
        :victim_ship_type_id,
        :attacker_count,
        :raw_data,
        :source
      ])
    end

    # Bulk create for ingestion pipeline
    create :ingest_from_source do
      description("Ingest raw killmail data from external source")

      accept([
        :killmail_id,
        :killmail_hash,
        :killmail_time,
        :solar_system_id,
        :victim_character_id,
        :victim_corporation_id,
        :victim_alliance_id,
        :victim_ship_type_id,
        :attacker_count,
        :raw_data,
        :source
      ])

      # Upsert behavior - if killmail already exists, do nothing
      upsert?(true)
      upsert_identity(:unique_killmail)
      # Don't update any fields on conflict - just ignore duplicates
      upsert_fields([])
    end

    # Custom read actions for common queries
    read :recent_kills do
      description("Get recent killmails ordered by time")

      prepare(build(sort: [killmail_time: :desc]))
    end

    read :by_system do
      description("Get killmails by solar system")

      argument :system_id, :integer do
        allow_nil?(false)
        description("Solar system ID to filter by")
      end

      filter(expr(solar_system_id == ^arg(:system_id)))
      prepare(build(sort: [killmail_time: :desc]))
    end

    read :by_victim_character do
      description("Get killmails where character was victim")

      argument :character_id, :integer do
        allow_nil?(false)
        description("Character ID to filter by")
      end

      filter(expr(victim_character_id == ^arg(:character_id)))
      prepare(build(sort: [killmail_time: :desc]))
    end
  end

  # Relationships
  relationships do
    has_many :participants, EveDmv.Killmails.Participant do
      source_attribute(:killmail_id)
      destination_attribute(:killmail_id)
      description("All participants (attackers and victim) in this killmail")
    end

    has_one :enriched_data, EveDmv.Killmails.KillmailEnriched do
      source_attribute(:killmail_id)
      destination_attribute(:killmail_id)
      description("Enriched analysis data for this killmail")
    end
  end

  # Authorization policies
  policies do
    # Allow read access for all authenticated users
    policy action_type(:read) do
      authorize_if(always())
    end

    # Only allow creates from the ingestion system
    policy action_type(:create) do
      # We'll implement service-level auth later
      authorize_if(always())
    end

    # No updates or deletes allowed
    policy action_type([:update, :destroy]) do
      forbid_if(always())
    end
  end

  # Aggregates for common calculations
  aggregates do
    count :participant_count, :participants do
      description("Number of participants in this killmail")
    end
  end

  # Calculations for derived values
  calculations do
    calculate :age_in_hours, :integer, expr(datetime_diff(now(), killmail_time, :hour)) do
      description("Age of the killmail in hours")
    end

    calculate(:is_recent, :boolean,
      description: "True if killmail is less than 24 hours old",
      calculation: expr(killmail_time > ago(24, :hour))
    )
  end
end
