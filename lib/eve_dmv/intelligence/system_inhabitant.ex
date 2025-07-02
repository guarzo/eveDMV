defmodule EveDmv.Intelligence.SystemInhabitant do
  @moduledoc """
  Tracks pilots present in wormhole systems within a chain.

  Provides real-time inhabitant tracking with threat assessment
  and historical presence data for chain-wide intelligence.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("system_inhabitants")
    repo(EveDmv.Repo)

    custom_indexes do
      index([:chain_topology_id, :system_id, :character_id], unique: true)
      index([:character_id, :last_seen_at])
      index([:corporation_id, :last_seen_at])
      index([:system_id, :present])
      index([:chain_topology_id, :present])
      index([:threat_level, :present])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :character_id, :integer do
      description("EVE character ID")
      allow_nil?(false)
    end

    attribute :character_name, :string do
      description("Character name (cached from ESI)")
      allow_nil?(false)
    end

    attribute :corporation_id, :integer do
      description("Character's corporation ID")
      allow_nil?(false)
    end

    attribute :corporation_name, :string do
      description("Corporation name (cached)")
      allow_nil?(false)
    end

    attribute :alliance_id, :integer do
      description("Character's alliance ID")
      allow_nil?(true)
    end

    attribute :alliance_name, :string do
      description("Alliance name (cached)")
      allow_nil?(true)
    end

    attribute :system_id, :integer do
      description("Solar system ID")
      allow_nil?(false)
    end

    attribute :system_name, :string do
      description("System name (cached)")
      allow_nil?(false)
    end

    attribute :ship_type_id, :integer do
      description("Ship type ID if known")
      allow_nil?(true)
    end

    attribute :ship_type_name, :string do
      description("Ship type name if known")
      allow_nil?(true)
    end

    attribute :present, :boolean do
      description("Whether pilot is currently present in system")
      allow_nil?(false)
      default(true)
    end

    attribute :first_seen_at, :utc_datetime_usec do
      description("First time pilot was seen in this system")
      allow_nil?(false)
      default(&DateTime.utc_now/0)
    end

    attribute :last_seen_at, :utc_datetime_usec do
      description("Last time pilot was confirmed present")
      allow_nil?(false)
      default(&DateTime.utc_now/0)
    end

    attribute :departure_time, :utc_datetime_usec do
      description("Time pilot left the system")
      allow_nil?(true)
    end

    attribute :threat_level, :atom do
      description("Threat assessment: friendly, neutral, hostile, unknown")
      constraints(one_of: [:friendly, :neutral, :hostile, :unknown])
      allow_nil?(false)
      default(:unknown)
    end

    attribute :threat_score, :integer do
      description("Calculated threat score (0-100)")
      allow_nil?(false)
      default(50)
    end

    attribute :bait_probability, :integer do
      description("Probability this is bait (0-100)")
      allow_nil?(false)
      default(25)
    end

    attribute :notes, :string do
      description("Intelligence notes about this pilot")
      allow_nil?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :chain_topology, EveDmv.Intelligence.ChainTopology do
      attribute_writable?(true)
    end

    belongs_to :ship_type, EveDmv.Eve.ItemType do
      source_attribute(:ship_type_id)
      destination_attribute(:type_id)
      description("Ship type information")
      attribute_writable?(false)
      allow_nil?(true)
    end

    belongs_to :solar_system, EveDmv.Eve.SolarSystem do
      source_attribute(:system_id)
      destination_attribute(:system_id)
      description("Solar system information")
      attribute_writable?(false)
      allow_nil?(true)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :character_id,
        :character_name,
        :corporation_id,
        :corporation_name,
        :alliance_id,
        :alliance_name,
        :system_id,
        :system_name,
        :ship_type_id,
        :ship_type_name,
        :chain_topology_id,
        :threat_level,
        :notes
      ])

      validate(
        present([:character_id, :character_name, :corporation_id, :system_id, :chain_topology_id])
      )

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:first_seen_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:last_seen_at, DateTime.utc_now())
      end)
    end

    update :update do
      primary?(true)

      accept([
        :character_name,
        :corporation_name,
        :alliance_id,
        :alliance_name,
        :ship_type_id,
        :ship_type_name,
        :threat_level,
        :threat_score,
        :bait_probability,
        :notes
      ])
    end

    update :mark_present do
      description("Update pilot as currently present")
      require_atomic?(false)

      accept([:ship_type_id, :ship_type_name])

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:present, true)
        |> Ash.Changeset.force_change_attribute(:last_seen_at, DateTime.utc_now())
        |> Ash.Changeset.force_change_attribute(:departure_time, nil)
      end)
    end

    update :mark_departed do
      description("Mark pilot as having left the system")
      require_atomic?(false)

      accept([])

      change(fn changeset, _context ->
        now = DateTime.utc_now()

        changeset
        |> Ash.Changeset.force_change_attribute(:present, false)
        |> Ash.Changeset.force_change_attribute(:departure_time, now)
      end)
    end

    update :update_threat_assessment do
      description("Update threat level and scores")

      accept([:threat_level, :threat_score, :bait_probability])
    end

    read :current_inhabitants do
      description("Currently present pilots")

      filter(expr(present == true))
    end

    read :by_chain do
      argument :chain_topology_id, :uuid do
        allow_nil?(false)
      end

      filter(expr(chain_topology_id == ^arg(:chain_topology_id)))
    end

    read :by_system do
      argument :system_id, :integer do
        allow_nil?(false)
      end

      filter(expr(system_id == ^arg(:system_id)))
    end

    read :by_character do
      argument :character_id, :integer do
        allow_nil?(false)
      end

      filter(expr(character_id == ^arg(:character_id)))
    end

    read :by_threat_level do
      argument :threat_level, :atom do
        allow_nil?(false)
      end

      filter(expr(threat_level == ^arg(:threat_level)))
    end

    read :hostiles do
      filter(expr(threat_level == :hostile and present == true))
    end

    read :recent_activity do
      argument :since_hours, :integer do
        default(4)
      end

      filter(expr(last_seen_at > ago(^arg(:since_hours), :hour)))
    end
  end

  calculations do
    calculate :minutes_present, :integer do
      description("Minutes pilot has been present in system")

      calculation(fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.present do
            DateTime.diff(now, record.first_seen_at, :minute)
          else
            case record.departure_time do
              nil -> 0
              departure -> DateTime.diff(departure, record.first_seen_at, :minute)
            end
          end
        end)
      end)
    end

    calculate :minutes_since_seen, :integer do
      description("Minutes since pilot was last seen")

      calculation(fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.last_seen_at, :minute)
        end)
      end)
    end

    calculate :display_status, :string do
      description("Human-readable status string")

      calculation(fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          if record.present do
            minutes = DateTime.diff(now, record.first_seen_at, :minute)

            if minutes < 60 do
              "Present (#{minutes}m)"
            else
              hours = div(minutes, 60)
              "Present (#{hours}h)"
            end
          else
            case record.departure_time do
              nil ->
                "Unknown"

              departure ->
                minutes = DateTime.diff(now, departure, :minute)

                if minutes < 60 do
                  "Left #{minutes}m ago"
                else
                  hours = div(minutes, 60)
                  "Left #{hours}h ago"
                end
            end
          end
        end)
      end)
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:mark_present, action: :mark_present)
    define(:mark_departed, action: :mark_departed)
    define(:update_threat_assessment, action: :update_threat_assessment)
    define(:current_inhabitants, action: :current_inhabitants)
    define(:by_chain, action: :by_chain, args: [:chain_topology_id])
    define(:by_system, action: :by_system, args: [:system_id])
    define(:by_character, action: :by_character, args: [:character_id])
    define(:by_threat_level, action: :by_threat_level, args: [:threat_level])
    define(:hostiles, action: :hostiles)
    define(:recent_activity, action: :recent_activity, args: [:since_hours])
  end
end
