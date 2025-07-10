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
end
