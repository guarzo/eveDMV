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

  alias EveDmv.Ash.Preparations.QuerySafety
  alias EveDmv.Core.Utils.DateTimeUtils

  require Ash.Query

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

    # Kill value (ISK)
    attribute :total_value, :decimal do
      allow_nil?(true)
      description("Total ISK value of the kill (ship + cargo)")
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

    # Participants JSONB column for efficient querying
    attribute :participants_data, :map do
      allow_nil?(true)
      description("Denormalized participant data for efficient battle detection queries")
      # Map to the actual database column name
      source(:participants)
    end

    # Automatic timestamp
    create_timestamp(:inserted_at)
  end

  # Identities for uniqueness
  identities do
    identity :unique_killmail_id, [:killmail_id] do
      description("Each killmail ID is globally unique")
    end

    # For partitioned tables, we need to include the partition key
    identity :unique_killmail_id_time, [:killmail_id, :killmail_time] do
      description("Killmail ID + time combination for partitioned table upsert")
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
        :total_value,
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
        :total_value,
        :raw_data,
        :source
      ])

      # Upsert behavior - if killmail already exists, do nothing
      upsert?(true)
      # Use the composite identity that includes partition key
      upsert_identity(:unique_killmail_id_time)
      # Don't update any fields on conflict - just ignore duplicates
      upsert_fields([])
    end

    # Custom read actions for common queries
    read :recent_kills do
      description("Get recent killmails within specified time window")

      argument :hours, :integer do
        allow_nil?(false)
        default(24)
        description("Number of hours to look back")
      end

      argument :system_id, :integer do
        allow_nil?(true)
        description("Optional: filter by solar system ID")
      end

      filter(expr(killmail_time >= ago(^arg(:hours), :hour)))
      filter(expr(is_nil(^arg(:system_id)) or solar_system_id == ^arg(:system_id)))

      prepare(build(sort: [killmail_time: :desc], limit: 100))
    end

    read :by_date_range do
      description("Get killmails within a date range")

      argument :start_date, :utc_datetime do
        allow_nil?(false)
        description("Start of date range (inclusive)")
      end

      argument :end_date, :utc_datetime do
        allow_nil?(false)
        description("End of date range (inclusive)")
      end

      filter(expr(killmail_time >= ^arg(:start_date) and killmail_time <= ^arg(:end_date)))

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

    read :by_character_involvement do
      description("Find killmails where character was involved as attacker or victim")

      argument :character_id, :integer do
        allow_nil?(false)
        description("Character ID to search for")
      end

      argument :since_days, :integer do
        allow_nil?(true)
        default(90)
        description("Number of days to look back")
      end

      argument :limit, :integer do
        allow_nil?(true)
        default(100)
        description("Maximum number of results")
      end

      prepare(fn query, context ->
        import Ash.Expr
        char_id = context.arguments.character_id
        days = context.arguments.since_days || 90
        result_limit = context.arguments.limit || 100
        since_date = DateTime.add(DateTime.utc_now(), -days, :day)

        query
        |> Ash.Query.filter(expr(killmail_time >= ^since_date))
        |> Ash.Query.filter(
          expr(
            victim_character_id == ^char_id or
              fragment(
                "EXISTS (SELECT 1 FROM participants p WHERE p.killmail_id = ? AND p.character_id = ? AND p.is_victim = false)",
                killmail_id,
                ^char_id
              )
          )
        )
        |> Ash.Query.sort(killmail_time: :desc)
        |> Ash.Query.limit(result_limit)
      end)
    end

    read :by_corporation_involvement do
      description("Find killmails involving a corporation")

      argument :corporation_id, :integer do
        allow_nil?(false)
        description("Corporation ID to search for")
      end

      argument :involvement_type, :atom do
        allow_nil?(true)
        default(:all)
        constraints(one_of: [:all, :kills, :losses])
        description("Filter by involvement type: all, kills, or losses")
      end

      argument :since_days, :integer do
        allow_nil?(true)
        default(90)
        description("Number of days to look back")
      end

      prepare(fn query, context ->
        import Ash.Expr
        corp_id = context.arguments.corporation_id
        involvement = context.arguments.involvement_type || :all
        days = context.arguments.since_days || 90
        since_date = DateTime.add(DateTime.utc_now(), -days, :day)

        query
        |> Ash.Query.filter(expr(killmail_time >= ^since_date))
        |> apply_corporation_filter(corp_id, involvement)
        |> Ash.Query.sort(killmail_time: :desc)
        |> Ash.Query.limit(100)
      end)
    end
  end

  # Relationships
  relationships do
    has_many :participants, EveDmv.Killmails.Participant do
      source_attribute(:killmail_id)
      destination_attribute(:killmail_id)
      description("All participants (attackers and victim) in this killmail")
    end

    has_many :attackers, EveDmv.Killmails.Participant do
      source_attribute(:killmail_id)
      destination_attribute(:killmail_id)
      filter(expr(is_victim == false))
      description("Only attackers in this killmail")
    end

    has_one :victim, EveDmv.Killmails.Participant do
      source_attribute(:killmail_id)
      destination_attribute(:killmail_id)
      filter(expr(is_victim == true))
      description("The victim in this killmail")
    end

    belongs_to :solar_system, EveDmv.Eve.SolarSystem do
      source_attribute(:solar_system_id)
      destination_attribute(:system_id)
      description("Solar system where the kill occurred")
    end

    belongs_to :victim_ship_type, EveDmv.Eve.ItemType do
      source_attribute(:victim_ship_type_id)
      destination_attribute(:type_id)
      description("Ship type that was destroyed")
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

    count :non_victim_count, :participants do
      description("Number of non-victim participants (attackers)")
      filter(expr(is_victim == false))
    end

    count :calculated_attacker_count, :attackers do
      description("Count of attackers (non-victim participants)")
    end

    sum :total_attacker_damage, :participants, :damage_done do
      description("Total damage dealt by all attackers")
      filter(expr(is_victim == false))
    end

    sum :total_damage_dealt, :attackers, :damage_done do
      description("Sum of all damage dealt by attackers")
    end

    first :final_blow_character_id, :attackers, :character_id do
      filter(expr(final_blow == true))
      description("Character who landed the final blow")
    end

    first :final_blow_character_name, :attackers, :character_name do
      filter(expr(final_blow == true))
      description("Name of character who landed the final blow")
    end

    first :top_damage_dealer_id, :attackers, :character_id do
      sort([{:damage_done, :desc}])
      description("Character who dealt the most damage")
    end

    max :max_single_damage, :attackers, :damage_done do
      description("Highest damage from a single attacker")
    end
  end

  # Preparations for query safety
  preparations do
    prepare(fn query, _ ->
      QuerySafety.prepare(query, [limit: 500], %{})
    end)
  end

  # Calculations for derived values
  calculations do
    calculate :age_in_hours, :integer do
      description("Age of the killmail in hours")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          DateTimeUtils.diff(DateTime.utc_now(), record.killmail_time, :hour)
        end)
      end)
    end

    calculate(:is_recent, :boolean,
      description: "True if killmail is less than 24 hours old",
      calculation: expr(killmail_time > ago(24, :hour))
    )

    calculate(:is_solo_kill, :boolean,
      description: "True if only one attacker was involved",
      calculation: expr(non_victim_count == 1)
    )

    calculate(:is_high_value, :boolean,
      description: "True if kill value exceeds 1 billion ISK",
      calculation: expr(total_value > 1_000_000_000)
    )

    calculate(:is_small_gang, :boolean,
      description: "True if this was a small gang kill (2-5 attackers)",
      calculation: expr(attacker_count >= 2 and attacker_count <= 5)
    )

    calculate(:is_fleet_kill, :boolean,
      description: "True if this was a fleet kill (>5 attackers)",
      calculation: expr(attacker_count > 5)
    )

    calculate :gang_size_category, :string do
      description(
        "Categorical gang size classification: solo, small_gang, medium_gang, large_gang, fleet"
      )

      calculation(fn records, _context ->
        Enum.map(records, fn killmail ->
          cond do
            killmail.attacker_count == 1 -> "solo"
            killmail.attacker_count <= 5 -> "small_gang"
            killmail.attacker_count <= 15 -> "medium_gang"
            killmail.attacker_count <= 50 -> "large_gang"
            true -> "fleet"
          end
        end)
      end)
    end

    calculate(:kill_age_hours, :integer,
      description: "Hours since this kill occurred",
      calculation:
        expr(fragment("EXTRACT(EPOCH FROM (NOW() - ?)) / 3600", killmail_time) |> type(:integer))
    )

    calculate :age_in_days, :integer do
      description("Age of the killmail in days")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          DateTimeUtils.diff(DateTime.utc_now(), record.killmail_time, :day)
        end)
      end)
    end

    calculate :time_of_day_bucket, :atom do
      description(
        "Time bucket based on UTC hour: :morning (6-11), :afternoon (12-17), :evening (18-21), :night (22-5)"
      )

      calculation(fn records, _context ->
        Enum.map(records, fn killmail ->
          hour = killmail.killmail_time.hour

          cond do
            hour >= 6 and hour < 12 -> :morning
            hour >= 12 and hour < 18 -> :afternoon
            hour >= 18 and hour < 22 -> :evening
            true -> :night
          end
        end)
      end)
    end

    calculate :day_of_week, :atom do
      description("Day of week: :monday through :sunday")

      calculation(fn records, _context ->
        Enum.map(records, fn killmail ->
          killmail.killmail_time
          |> DateTime.to_date()
          |> Date.day_of_week()
          |> day_number_to_atom()
        end)
      end)
    end

    calculate :security_class, :string do
      description(
        "Security classification from solar system (highsec, lowsec, nullsec, wormhole)"
      )

      load([:solar_system])

      calculation(fn records, _context ->
        Enum.map(records, fn killmail ->
          case killmail.solar_system do
            nil -> "unknown"
            sys -> sys.security_class || "unknown"
          end
        end)
      end)
    end

    calculate :is_wormhole_kill, :boolean do
      description("Whether this kill occurred in wormhole space")
      load([:solar_system])

      calculation(fn records, _context ->
        Enum.map(records, fn killmail ->
          case killmail.solar_system do
            nil -> false
            sys -> sys.security_class == "wormhole"
          end
        end)
      end)
    end
  end

  # Helper function for day_of_week calculation
  defp day_number_to_atom(1), do: :monday
  defp day_number_to_atom(2), do: :tuesday
  defp day_number_to_atom(3), do: :wednesday
  defp day_number_to_atom(4), do: :thursday
  defp day_number_to_atom(5), do: :friday
  defp day_number_to_atom(6), do: :saturday
  defp day_number_to_atom(7), do: :sunday

  # Helper functions for read actions

  @doc false
  defp apply_corporation_filter(query, corp_id, :all) do
    import Ash.Expr

    Ash.Query.filter(
      query,
      expr(
        victim_corporation_id == ^corp_id or
          fragment(
            "EXISTS (SELECT 1 FROM participants p WHERE p.killmail_id = ? AND p.corporation_id = ?)",
            killmail_id,
            ^corp_id
          )
      )
    )
  end

  defp apply_corporation_filter(query, corp_id, :losses) do
    import Ash.Expr
    Ash.Query.filter(query, expr(victim_corporation_id == ^corp_id))
  end

  defp apply_corporation_filter(query, corp_id, :kills) do
    import Ash.Expr

    Ash.Query.filter(
      query,
      expr(
        fragment(
          "EXISTS (SELECT 1 FROM participants p WHERE p.killmail_id = ? AND p.corporation_id = ? AND p.is_victim = false)",
          killmail_id,
          ^corp_id
        )
      )
    )
  end
end
