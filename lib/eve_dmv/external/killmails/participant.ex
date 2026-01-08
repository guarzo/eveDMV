defmodule EveDmv.Killmails.Participant do
  @moduledoc """
  Participant resource for individual characters, corporations, and alliances in killmails.

  This resource stores information about each participant (both attackers and victim)
  in a killmail, including their ship, weapon used, damage dealt, and final blow status.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("participants")
    repo(EveDmv.Repo)

    # Disable foreign keys for ship_type and weapon_type relationships.
    # Killmails can reference item types that aren't in our filtered SDE import
    # (e.g., SKINs, apparel, structures, or unpublished items).
    # We keep the relationships for preloading but skip the FK constraints.
    references do
      reference(:ship_type, ignore?: true)
      reference(:weapon_type, ignore?: true)
    end

    custom_indexes do
      index([:killmail_id, :killmail_time], name: "participants_killmail_idx")
      index([:character_id], name: "participants_character_idx")
      index([:corporation_id], name: "participants_corporation_idx")
      index([:alliance_id], name: "participants_alliance_idx")
      index([:ship_type_id], name: "participants_ship_type_idx")
      index([:is_victim], name: "participants_victim_idx")
      index([:final_blow], name: "participants_final_blow_idx")
      index([:killmail_time], name: "participants_time_idx")
    end
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api)
    define(:read, action: :read)
    define(:create, action: :create)
    define(:by_killmail, args: [:killmail_id, :killmail_time])
    define(:by_character, args: [:character_id])
    define(:by_corporation, args: [:corporation_id])
    define(:attackers_only, args: [:killmail_id, :killmail_time])
    define(:victims_only, args: [:killmail_id, :killmail_time])
    define(:character_activity_summary, args: [:character_id])
    define(:search_characters_by_name, args: [:query])
    define(:search_corporations_by_name, args: [:query])
  end

  # Attributes
  attributes do
    # Primary key
    uuid_primary_key(:id)

    # Killmail reference
    attribute :killmail_id, :integer do
      allow_nil?(false)
      description("EVE killmail ID this participant belongs to")
    end

    attribute :killmail_time, :utc_datetime do
      allow_nil?(false)
      description("Kill timestamp for partitioning")
    end

    # Character information
    attribute :character_id, :integer do
      allow_nil?(true)
      description("EVE character ID (null for NPCs)")
    end

    attribute :character_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("EVE character name")
    end

    # Corporation information
    attribute :corporation_id, :integer do
      allow_nil?(true)
      description("EVE corporation ID")
    end

    attribute :corporation_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("EVE corporation name")
    end

    # Alliance information
    attribute :alliance_id, :integer do
      allow_nil?(true)
      description("EVE alliance ID")
    end

    attribute :alliance_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("EVE alliance name")
    end

    # Faction information (for faction warfare)
    attribute :faction_id, :integer do
      allow_nil?(true)
      description("EVE faction ID for faction warfare participants")
    end

    attribute :faction_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("EVE faction name")
    end

    # Ship information
    attribute :ship_type_id, :integer do
      allow_nil?(false)
      description("Type ID of the ship used by this participant")
    end

    attribute :ship_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Name of the ship type")
    end

    # Weapon information
    attribute :weapon_type_id, :integer do
      allow_nil?(true)
      description("Type ID of the weapon that dealt damage")
    end

    attribute :weapon_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Name of the weapon type")
    end

    # Combat details
    attribute :damage_done, :integer do
      allow_nil?(false)
      default(0)
      description("Amount of damage dealt to the victim")
    end

    attribute :security_status, :decimal do
      allow_nil?(true)
      constraints(precision: 5, scale: 2)
      description("Security status of the character")
    end

    # Participant role flags
    attribute :is_victim, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether this participant is the victim")
    end

    attribute :final_blow, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether this participant landed the final blow")
    end

    attribute :is_npc, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether this participant is an NPC")
    end

    # Location at time of kill
    attribute :solar_system_id, :integer do
      allow_nil?(false)
      description("Solar system where the participant was located")
    end

    # Automatic timestamps
    timestamps()
  end

  # Identities
  identities do
    identity :unique_participant_per_killmail, [
      :killmail_id,
      :killmail_time,
      :character_id,
      :ship_type_id
    ] do
      description("Each character can only appear once per killmail with a given ship")
    end
  end

  # Relationships
  relationships do
    # Note: Composite foreign key relationships removed for now
    # Will be implemented using manual queries in Epic 2

    # Re-enabled now that EVE static data is loaded
    belongs_to :ship_type, EveDmv.Eve.ItemType do
      source_attribute(:ship_type_id)
      destination_attribute(:type_id)
      description("Ship type information")
    end

    belongs_to :weapon_type, EveDmv.Eve.ItemType do
      source_attribute(:weapon_type_id)
      destination_attribute(:type_id)
      description("Weapon type information")
    end
  end

  # Actions
  actions do
    # Default actions
    defaults([:read, :update, :destroy])

    # Custom create action
    create :create do
      primary?(true)
      description("Create a participant record")

      accept([
        :killmail_id,
        :killmail_time,
        :character_id,
        :character_name,
        :corporation_id,
        :corporation_name,
        :alliance_id,
        :alliance_name,
        :faction_id,
        :faction_name,
        :ship_type_id,
        :ship_name,
        :weapon_type_id,
        :weapon_name,
        :damage_done,
        :security_status,
        :is_victim,
        :final_blow,
        :is_npc,
        :solar_system_id
      ])

      # Upsert to handle duplicate processing
      upsert?(true)
      upsert_identity(:unique_participant_per_killmail)
      # Don't update any fields on conflict - just ignore duplicates
      upsert_fields([])
    end

    # Read actions for specific queries
    read :by_killmail do
      description("Get all participants for a specific killmail")

      argument :killmail_id, :integer do
        allow_nil?(false)
        description("Killmail ID to get participants for")
      end

      argument :killmail_time, :utc_datetime do
        allow_nil?(false)
        description("Killmail timestamp")
      end

      filter(expr(killmail_id == ^arg(:killmail_id) and killmail_time == ^arg(:killmail_time)))
      prepare(build(sort: [:is_victim, :final_blow, :damage_done]))
    end

    read :by_character do
      description("Get killmail participation history for a character")

      argument :character_id, :integer do
        allow_nil?(false)
        description("Character ID to search for")
      end

      filter(expr(character_id == ^arg(:character_id)))
      prepare(build(sort: [killmail_time: :desc]))
    end

    read :attackers_only do
      description("Get only attackers for a specific killmail")

      argument :killmail_id, :integer do
        allow_nil?(false)
        description("Killmail ID")
      end

      argument :killmail_time, :utc_datetime do
        allow_nil?(false)
        description("Killmail timestamp")
      end

      filter(
        expr(
          killmail_id == ^arg(:killmail_id) and
            killmail_time == ^arg(:killmail_time) and
            is_victim == false
        )
      )

      prepare(build(sort: [damage_done: :desc]))
    end

    read :victims_only do
      description("Get only victims for a specific killmail")

      argument :killmail_id, :integer do
        allow_nil?(false)
        description("Killmail ID")
      end

      argument :killmail_time, :utc_datetime do
        allow_nil?(false)
        description("Killmail timestamp")
      end

      filter(
        expr(
          killmail_id == ^arg(:killmail_id) and
            killmail_time == ^arg(:killmail_time) and
            is_victim == true
        )
      )
    end

    read :recent_activity do
      description("Get recent participant activity")

      argument :hours, :integer do
        allow_nil?(false)
        default(24)
        description("Number of hours to look back")
      end

      filter(expr(killmail_time >= ago(^arg(:hours), :hour)))
      prepare(build(sort: [killmail_time: :desc]))
    end

    read :by_corporation do
      description("Get participants by corporation")

      argument :corporation_id, :integer do
        allow_nil?(false)
        description("Corporation ID to search for")
      end

      filter(expr(corporation_id == ^arg(:corporation_id)))
      prepare(build(sort: [killmail_time: :desc]))
    end

    read :by_alliance do
      description("Get participants by alliance")

      argument :alliance_id, :integer do
        allow_nil?(false)
        description("Alliance ID to search for")
      end

      filter(expr(alliance_id == ^arg(:alliance_id)))
      prepare(build(sort: [killmail_time: :desc]))
    end

    read :search_characters_by_name do
      description("Search for characters by name with ILIKE matching")

      argument :query, :string do
        allow_nil?(false)
        description("Search query to match against character names")
      end

      argument :limit, :integer do
        allow_nil?(false)
        default(10)
        description("Maximum number of results to return")
      end

      filter(expr(not is_nil(character_id) and not is_nil(character_name)))

      prepare(fn query, context ->
        search_pattern = "%#{context.arguments.query}%"

        query
        |> Ash.Query.filter_input(%{character_name: %{ilike: search_pattern}})
        |> Ash.Query.sort(killmail_time: :desc)
        |> Ash.Query.distinct([:character_id])
        |> Ash.Query.limit(context.arguments.limit)
        |> Ash.Query.select([
          :character_id,
          :character_name,
          :corporation_id,
          :corporation_name,
          :alliance_id,
          :alliance_name,
          :killmail_time
        ])
      end)
    end

    read :search_corporations_by_name do
      description("Search for corporations by name with ILIKE matching")

      argument :query, :string do
        allow_nil?(false)
        description("Search query to match against corporation names")
      end

      argument :limit, :integer do
        allow_nil?(false)
        default(10)
        description("Maximum number of results to return")
      end

      filter(expr(not is_nil(corporation_id) and not is_nil(corporation_name)))

      prepare(fn query, context ->
        search_pattern = "%#{context.arguments.query}%"

        query
        |> Ash.Query.filter_input(%{corporation_name: %{ilike: search_pattern}})
        |> Ash.Query.sort(killmail_time: :desc)
        |> Ash.Query.distinct([:corporation_id])
        |> Ash.Query.limit(context.arguments.limit)
        |> Ash.Query.select([
          :corporation_id,
          :corporation_name,
          :alliance_id,
          :alliance_name,
          :killmail_time
        ])
      end)
    end

    read :character_activity_summary do
      description("Get activity summary for a character with kill/loss breakdown")

      argument :character_id, :integer do
        allow_nil?(false)
        description("Character ID to get activity summary for")
      end

      argument :since_days, :integer do
        allow_nil?(false)
        default(90)
        description("Number of days to look back")
      end

      pagination do
        offset?(true)
        default_limit(50)
        max_page_size(100)
      end

      filter(expr(character_id == ^arg(:character_id)))
      filter(expr(killmail_time >= ago(^arg(:since_days), :day)))

      prepare(build(sort: [killmail_time: :desc], load: [:ship_type, :participation_type]))
    end

    read :character_kill_stats do
      description("Get aggregated kill statistics for a character")

      argument :character_id, :integer do
        allow_nil?(false)
        description("Character ID to get stats for")
      end

      argument :since_days, :integer do
        allow_nil?(false)
        default(90)
        description("Number of days to look back")
      end

      filter(expr(character_id == ^arg(:character_id)))
      filter(expr(killmail_time >= ago(^arg(:since_days), :day)))
      filter(expr(is_victim == false))

      prepare(fn query, _context ->
        query
        |> Ash.Query.aggregate(:total_kills, :count)
        |> Ash.Query.aggregate(:total_damage, :sum, :damage_done)
        |> Ash.Query.aggregate(:final_blows, :count, filter: expr(final_blow == true))
      end)
    end

    read :character_loss_stats do
      description("Get aggregated loss statistics for a character")

      argument :character_id, :integer do
        allow_nil?(false)
        description("Character ID to get stats for")
      end

      argument :since_days, :integer do
        allow_nil?(false)
        default(90)
        description("Number of days to look back")
      end

      filter(expr(character_id == ^arg(:character_id)))
      filter(expr(killmail_time >= ago(^arg(:since_days), :day)))
      filter(expr(is_victim == true))

      prepare(fn query, _context ->
        query
        |> Ash.Query.aggregate(:total_losses, :count)
      end)
    end

    # NOTE: This read action is deprecated due to incorrect aggregation behavior.
    # The aggregate+distinct pattern does not properly group counts per ship.
    # Use EveDmv.Killmails.Participant.get_character_ship_usage/3 instead,
    # which performs a proper GROUP BY query with correct per-ship counts.
    read :character_ship_usage do
      description(
        "DEPRECATED: Use get_character_ship_usage/3 function instead. " <>
          "This action has incorrect aggregation behavior."
      )

      argument :character_id, :integer do
        allow_nil?(false)
        description("Character ID to get ship usage for")
      end

      argument :since_days, :integer do
        allow_nil?(false)
        default(90)
        description("Number of days to look back")
      end

      argument :limit, :integer do
        allow_nil?(false)
        default(10)
        description("Maximum number of ships to return")
      end

      filter(expr(character_id == ^arg(:character_id)))
      filter(expr(killmail_time >= ago(^arg(:since_days), :day)))
      filter(expr(is_victim == false))

      # This prepare block has incorrect behavior - the aggregate counts all
      # matching records rather than per-group. Kept for backwards compatibility
      # but callers should migrate to get_character_ship_usage/3.
      prepare(fn query, context ->
        query
        |> Ash.Query.aggregate(:usage_count, :count)
        |> Ash.Query.distinct([:ship_type_id, :ship_name])
        |> Ash.Query.sort(usage_count: :desc)
        |> Ash.Query.limit(context.arguments.limit)
        |> Ash.Query.select([:ship_type_id, :ship_name])
      end)
    end

    # Bulk read actions for efficient multi-record fetching

    read :by_killmail_ids do
      description("Get participants for multiple killmails efficiently")

      argument :killmail_ids, {:array, :integer} do
        allow_nil?(false)
        description("List of killmail IDs to fetch participants for")
      end

      filter(expr(killmail_id in ^arg(:killmail_ids)))

      prepare(build(sort: [:killmail_id, :is_victim, {:damage_done, :desc}]))
    end

    read :by_character_ids do
      description("Get recent activity for multiple characters")

      argument :character_ids, {:array, :integer} do
        allow_nil?(false)
        description("List of character IDs to fetch activity for")
      end

      argument :since_days, :integer do
        allow_nil?(false)
        default(90)
        description("Number of days to look back")
      end

      filter(expr(character_id in ^arg(:character_ids)))
      filter(expr(killmail_time >= ago(^arg(:since_days), :day)))

      prepare(build(sort: [killmail_time: :desc]))
    end

    read :corporation_activity do
      description("Get corporation member activity with aggregation")

      argument :corporation_id, :integer do
        allow_nil?(false)
        description("Corporation ID to get activity for")
      end

      argument :since_days, :integer do
        allow_nil?(false)
        default(30)
        description("Number of days to look back")
      end

      filter(expr(corporation_id == ^arg(:corporation_id)))
      filter(expr(killmail_time >= ago(^arg(:since_days), :day)))
      # Exclude NPCs - only count actual corporation members
      filter(expr(is_npc == false))

      prepare(fn query, _context ->
        query
        |> Ash.Query.aggregate(:total_activity, :count)
        |> Ash.Query.aggregate(:total_kills, :count, filter: expr(is_victim == false))
        |> Ash.Query.aggregate(:total_losses, :count, filter: expr(is_victim == true))
        |> Ash.Query.aggregate(:unique_members, :count, field: :character_id, uniq?: true)
      end)
    end

    read :system_activity_summary do
      description("Get activity summary for a solar system (player activity only)")

      argument :system_id, :integer do
        allow_nil?(false)
        description("Solar system ID to get activity for")
      end

      argument :since_hours, :integer do
        allow_nil?(false)
        default(24)
        description("Number of hours to look back")
      end

      filter(expr(solar_system_id == ^arg(:system_id)))
      filter(expr(killmail_time >= ago(^arg(:since_hours), :hour)))
      # Exclude NPCs - system activity measures player presence
      filter(expr(is_npc == false))

      prepare(fn query, _context ->
        query
        |> Ash.Query.aggregate(:total_participants, :count)
        |> Ash.Query.aggregate(:unique_characters, :count, field: :character_id, uniq?: true)
        |> Ash.Query.aggregate(:unique_corporations, :count, field: :corporation_id, uniq?: true)
        |> Ash.Query.aggregate(:total_kills, :count, filter: expr(is_victim == false))
      end)
    end
  end

  # Aggregates
  aggregates do
    # Note: Aggregates removed for now
    # Will be re-added in Epic 2 when relationships are properly configured
  end

  # Calculations
  calculations do
    calculate :damage_percentage,
              :decimal,
              expr(damage_done / max(sum(damage_done, field: :damage_done), 1) * 100) do
      description("Percentage of total damage dealt by this participant")
    end

    calculate :is_solo_kill, :boolean, expr(count(:*, field: :id) == 2) do
      description("Whether this was a solo kill (victim + 1 attacker)")
    end

    calculate :participation_type, :string do
      description("Type of participation (victim, final_blow, attacker)")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          cond do
            record.is_victim -> "victim"
            record.final_blow -> "final_blow"
            true -> "attacker"
          end
        end)
      end)
    end

    calculate :threat_level, :atom do
      description(
        "Calculated threat level based on damage and role: :low, :medium, :high, :extreme"
      )

      calculation(fn records, _context ->
        Enum.map(records, fn participant ->
          cond do
            participant.is_victim -> :none
            participant.final_blow and participant.damage_done > 10_000 -> :extreme
            participant.final_blow -> :high
            participant.damage_done > 5_000 -> :medium
            true -> :low
          end
        end)
      end)
    end

    calculate :ship_category, :string do
      description("Ship category from EVE SDE group classification")
      load([:ship_type])

      calculation(fn records, _context ->
        Enum.map(records, fn participant ->
          case participant.ship_type do
            nil -> "Unknown"
            ship -> ship.group_name || "Unknown"
          end
        end)
      end)
    end

    calculate :significant_contribution?, :boolean do
      description("True if damage >= 10% of total killmail damage or landed final blow")

      calculation(fn records, _context ->
        Enum.map(records, fn participant ->
          participant.final_blow == true or
            (is_number(participant.damage_done) and participant.damage_done >= 1000)
        end)
      end)
    end
  end

  # Authorization policies
  policies do
    # Public read access for anonymized data
    policy action_type(:read) do
      authorize_if(always())
    end

    # Only authenticated users can create/modify participant data
    policy action_type([:create, :update, :destroy]) do
      authorize_if(actor_present())
    end
  end

  @doc """
  Get ship usage breakdown for a character with proper grouping.

  Returns a list of maps with :ship_type_id, :ship_name, and :usage_count,
  ordered by usage_count descending.

  ## Parameters
    - character_id: The EVE character ID
    - since_days: Number of days to look back (default: 90)
    - limit: Maximum number of ships to return (default: 10)

  ## Examples

      iex> EveDmv.Killmails.Participant.get_character_ship_usage(12345)
      {:ok, [%{ship_type_id: 587, ship_name: "Rifter", usage_count: 42}, ...]}

  """
  @spec get_character_ship_usage(integer(), integer(), integer()) ::
          {:ok, [map()]} | {:error, term()}
  def get_character_ship_usage(character_id, since_days \\ 90, limit \\ 10) do
    since_date = DateTime.utc_now() |> DateTime.add(-since_days, :day)

    query = """
    SELECT
      ship_type_id,
      ship_name,
      COUNT(*) as usage_count
    FROM participants
    WHERE character_id = $1
      AND killmail_time >= $2
      AND is_victim = false
    GROUP BY ship_type_id, ship_name
    ORDER BY usage_count DESC
    LIMIT $3
    """

    case Ecto.Adapters.SQL.query(EveDmv.Repo, query, [character_id, since_date, limit]) do
      {:ok, %{rows: rows}} ->
        results =
          Enum.map(rows, fn [ship_type_id, ship_name, usage_count] ->
            %{
              ship_type_id: ship_type_id,
              ship_name: ship_name,
              usage_count: usage_count
            }
          end)

        {:ok, results}

      {:error, error} ->
        {:error, error}
    end
  end
end
