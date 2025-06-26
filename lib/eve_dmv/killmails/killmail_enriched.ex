defmodule EveDmv.Killmails.KillmailEnriched do
  @moduledoc """
  Enriched killmail resource with ISK values, ship analysis, and processed data.

  This resource contains the processed and analyzed version of raw killmail data,
  including ISK calculations, ship type analysis, and other derived metrics.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("killmails_enriched")
    repo(EveDmv.Repo)

    # Composite primary key for partitioning
    custom_indexes do
      index([:killmail_time], name: "killmails_enriched_time_idx")
      index([:victim_character_id], name: "killmails_enriched_victim_character_idx")
      index([:victim_corporation_id], name: "killmails_enriched_victim_corp_idx")
      index([:victim_alliance_id], name: "killmails_enriched_victim_alliance_idx")
      index([:solar_system_id], name: "killmails_enriched_system_idx")
      index([:total_value], name: "killmails_enriched_value_idx")
    end
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api)
    define(:read, action: :read)
    define(:create, action: :create)
    define(:by_system, args: [:solar_system_id])
    define(:high_value, args: [:min_value])
    define(:recent_enriched, args: [:hours])
  end

  # Attributes
  attributes do
    # Composite primary key matching raw killmails
    attribute :killmail_id, :integer do
      allow_nil?(false)
      primary_key?(true)
      description("EVE killmail ID from zKillboard/ESI")
    end

    attribute :killmail_time, :utc_datetime do
      allow_nil?(false)
      primary_key?(true)
      description("When the kill occurred - used for partitioning")
    end

    # Victim information (denormalized for performance)
    attribute :victim_character_id, :integer do
      allow_nil?(true)
      description("Victim character ID")
    end

    attribute :victim_character_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Victim character name")
    end

    attribute :victim_corporation_id, :integer do
      allow_nil?(true)
      description("Victim corporation ID")
    end

    attribute :victim_corporation_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Victim corporation name")
    end

    attribute :victim_alliance_id, :integer do
      allow_nil?(true)
      description("Victim alliance ID")
    end

    attribute :victim_alliance_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Victim alliance name")
    end

    # Location information
    attribute :solar_system_id, :integer do
      allow_nil?(false)
      description("Solar system where kill occurred")
    end

    attribute :solar_system_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Solar system name")
    end

    # Ship and fitting information
    attribute :victim_ship_type_id, :integer do
      allow_nil?(false)
      description("Type ID of the destroyed ship")
    end

    attribute :victim_ship_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Name of the destroyed ship type")
    end

    # ISK value calculations
    attribute :total_value, :decimal do
      allow_nil?(true)
      constraints(precision: 15, scale: 2)
      description("Total estimated ISK value of the loss")
    end

    attribute :ship_value, :decimal do
      allow_nil?(true)
      constraints(precision: 15, scale: 2)
      description("Estimated ISK value of the ship hull")
    end

    attribute :fitted_value, :decimal do
      allow_nil?(true)
      constraints(precision: 15, scale: 2)
      description("Estimated ISK value of fitted modules and cargo")
    end

    # Combat analysis
    attribute :attacker_count, :integer do
      allow_nil?(false)
      default(0)
      description("Number of attackers involved")
    end

    attribute :final_blow_character_id, :integer do
      allow_nil?(true)
      description("Character ID who landed the final blow")
    end

    attribute :final_blow_character_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Character name who landed the final blow")
    end

    # Categorization
    attribute :kill_category, :string do
      allow_nil?(true)
      constraints(max_length: 50)
      description("Kill category (solo, small_gang, fleet, etc.)")
    end

    attribute :victim_ship_category, :string do
      allow_nil?(true)
      constraints(max_length: 50)
      description("Ship category (frigate, cruiser, battleship, etc.)")
    end

    # Module and fitting analysis
    attribute :module_tags, {:array, :string} do
      allow_nil?(true)
      default([])
      description("Tags for fitted modules (pvp, pve, mining, etc.)")
    end

    attribute :noteworthy_modules, {:array, :string} do
      allow_nil?(true)
      default([])
      description("List of high-value or notable fitted modules")
    end

    # Processing metadata
    attribute :enriched_at, :utc_datetime do
      allow_nil?(true)
      description("When this killmail was enriched/processed")
    end

    attribute :price_data_source, :string do
      allow_nil?(true)
      constraints(max_length: 50)
      description("Source of price data (janice, mutamarket, eve_praisal)")
    end

    # Automatic timestamps
    timestamps()
  end

  # Identities for uniqueness
  identities do
    identity :unique_killmail, [:killmail_id, :killmail_time] do
      description("Each killmail ID + time combination is unique")
    end
  end

  # Relationships
  relationships do
    # Note: Composite foreign key relationships removed for now
    # Will be implemented using manual queries in Epic 2
  end

  # Actions
  actions do
    # Default actions
    defaults([:read, :update, :destroy])

    # Custom create action for enrichment pipeline
    create :create do
      primary?(true)
      description("Create enriched killmail data")

      accept([
        :killmail_id,
        :killmail_time,
        :victim_character_id,
        :victim_character_name,
        :victim_corporation_id,
        :victim_corporation_name,
        :victim_alliance_id,
        :victim_alliance_name,
        :solar_system_id,
        :solar_system_name,
        :victim_ship_type_id,
        :victim_ship_name,
        :total_value,
        :ship_value,
        :fitted_value,
        :attacker_count,
        :final_blow_character_id,
        :final_blow_character_name,
        :kill_category,
        :victim_ship_category,
        :module_tags,
        :noteworthy_modules,
        :price_data_source
      ])

      change(set_attribute(:enriched_at, &DateTime.utc_now/0))
    end

    # Read actions for different queries
    read :by_system do
      description("Get enriched killmails for a specific solar system")

      argument :solar_system_id, :integer do
        allow_nil?(false)
        description("Solar system ID to filter by")
      end

      filter(expr(solar_system_id == ^arg(:solar_system_id)))
    end

    read :high_value do
      description("Get high-value killmails above a threshold")

      argument :min_value, :decimal do
        allow_nil?(false)
        description("Minimum ISK value threshold")
      end

      filter(expr(total_value >= ^arg(:min_value)))
      prepare(build(sort: [:total_value, :killmail_time]))
    end

    read :recent_enriched do
      description("Get recently enriched killmails")

      argument :hours, :integer do
        allow_nil?(false)
        default(24)
        description("Number of hours to look back")
      end

      filter(expr(enriched_at >= ago(^arg(:hours), :hour)))
      prepare(build(sort: [killmail_time: :desc]))
    end
  end

  # Aggregates and calculations
  aggregates do
    # Note: Aggregates removed for now due to missing relationships
    # Will be re-added in Epic 2 with manual queries
  end

  calculations do
    calculate :kill_efficiency, :decimal, expr(ship_value / (ship_value + fitted_value)) do
      description("Ratio of ship value to total value (efficiency metric)")
    end

    calculate :age_hours, :integer, expr(datetime_diff(now(), killmail_time, :hour)) do
      description("Age of the killmail in hours")
    end

    calculate :is_high_value, :boolean, expr(total_value > 1_000_000_000) do
      description("Whether this is considered a high-value kill (>1B ISK)")
    end
  end

  # Authorization policies
  policies do
    # Public read access for most data
    policy action_type(:read) do
      authorize_if(always())
    end

    # Only authenticated users can create/modify enriched data
    policy action_type([:create, :update, :destroy]) do
      authorize_if(actor_present())
    end
  end
end
