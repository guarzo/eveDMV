defmodule EveDmv.Intelligence.ChainAnalysis.ChainConnection do
  @moduledoc """
  Represents wormhole connections within a chain topology.

  Tracks connection status, mass, time remaining, and signatures
  for wormhole intelligence and navigation planning.
  """

  use Ash.Resource,
    domain: EveDmv.Domains.Intelligence,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("chain_connections")
    repo(EveDmv.Repo)

    custom_indexes do
      index([:chain_topology_id, :source_system_id, :target_system_id], unique: true)
      index([:signature_id], unique: true, where: "signature_id IS NOT NULL")
      index([:connection_type])
      index([:mass_status])
      index([:time_status])
      index([:is_eol])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :source_system_id, :integer do
      description("Source solar system ID")
      allow_nil?(false)
    end

    attribute :source_system_name, :string do
      description("Source system name (cached)")
      allow_nil?(false)
    end

    attribute :target_system_id, :integer do
      description("Target solar system ID")
      allow_nil?(false)
    end

    attribute :target_system_name, :string do
      description("Target system name (cached)")
      allow_nil?(false)
    end

    attribute :connection_type, :atom do
      description("Type of connection: static, wandering, k162")
      constraints(one_of: [:static, :wandering, :k162, :unknown])
      allow_nil?(false)
      default(:unknown)
    end

    attribute :wormhole_type, :string do
      description("Wormhole signature type (A239, K162, etc.)")
      allow_nil?(true)
    end

    attribute :signature_id, :string do
      description("Signature ID (ABC-123)")
      allow_nil?(true)
    end

    attribute :mass_status, :atom do
      description("Mass status: stable, destab, critical")
      constraints(one_of: [:stable, :destab, :critical, :unknown])
      allow_nil?(false)
      default(:unknown)
    end

    attribute :time_status, :atom do
      description("Time status: stable, eol")
      constraints(one_of: [:stable, :eol, :unknown])
      allow_nil?(false)
      default(:unknown)
    end

    attribute :is_eol, :boolean do
      description("Whether connection is end-of-life")
      allow_nil?(false)
      default(false)
    end

    attribute :mass_remaining_percent, :integer do
      description("Estimated mass remaining (0-100)")
      allow_nil?(true)
    end

    attribute :estimated_eol_time, :utc_datetime_usec do
      description("Estimated time when connection expires")
      allow_nil?(true)
    end

    attribute :first_discovered_at, :utc_datetime_usec do
      description("When this connection was first discovered")
      allow_nil?(false)
      default(&DateTime.utc_now/0)
    end

    attribute :last_updated_at, :utc_datetime_usec do
      description("Last time connection status was updated")
      allow_nil?(false)
      default(&DateTime.utc_now/0)
    end

    attribute :last_transit_at, :utc_datetime_usec do
      description("Last recorded transit through this connection")
      allow_nil?(true)
    end

    attribute :ship_restrictions, :map do
      description("Ship size/mass restrictions")
      allow_nil?(false)
      default(%{})
    end

    attribute :notes, :string do
      description("Additional notes about this connection")
      allow_nil?(true)
    end

    timestamps()
  end

  relationships do
    belongs_to :chain_topology, EveDmv.Intelligence.ChainAnalysis.ChainTopology do
      attribute_writable?(true)
    end

    belongs_to :source_system, EveDmv.Eve.SolarSystem do
      source_attribute(:source_system_id)
      destination_attribute(:system_id)
      description("Source solar system")
      attribute_writable?(false)
      allow_nil?(false)
    end

    belongs_to :target_system, EveDmv.Eve.SolarSystem do
      source_attribute(:target_system_id)
      destination_attribute(:system_id)
      description("Target solar system")
      attribute_writable?(false)
      allow_nil?(false)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :source_system_id,
        :source_system_name,
        :target_system_id,
        :target_system_name,
        :connection_type,
        :wormhole_type,
        :signature_id,
        :chain_topology_id,
        :ship_restrictions,
        :notes
      ])

      validate(
        present([
          :source_system_id,
          :source_system_name,
          :target_system_id,
          :target_system_name,
          :chain_topology_id
        ])
      )

      change(fn changeset, _context ->
        now = DateTime.utc_now()

        changeset
        |> Ash.Changeset.force_change_attribute(:first_discovered_at, now)
        |> Ash.Changeset.force_change_attribute(:last_updated_at, now)
      end)
    end

    update :update do
      primary?(true)
      require_atomic?(false)

      accept([
        :connection_type,
        :wormhole_type,
        :signature_id,
        :mass_status,
        :time_status,
        :is_eol,
        :mass_remaining_percent,
        :estimated_eol_time,
        :ship_restrictions,
        :notes
      ])

      change(fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :last_updated_at, DateTime.utc_now())
      end)
    end

    update :update_mass_status do
      description("Update mass and time status")
      require_atomic?(false)

      accept([:mass_status, :time_status, :is_eol, :mass_remaining_percent, :estimated_eol_time])

      change(fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :last_updated_at, DateTime.utc_now())
      end)
    end

    update :record_transit do
      description("Record a ship transit through this connection")
      require_atomic?(false)

      accept([])

      change(fn changeset, _context ->
        now = DateTime.utc_now()

        changeset
        |> Ash.Changeset.force_change_attribute(:last_transit_at, now)
        |> Ash.Changeset.force_change_attribute(:last_updated_at, now)
      end)
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

      filter(
        expr(
          source_system_id == ^arg(:system_id) or
            target_system_id == ^arg(:system_id)
        )
      )
    end

    read :by_signature do
      argument :signature_id, :string do
        allow_nil?(false)
      end

      filter(expr(signature_id == ^arg(:signature_id)))
    end

    read :critical_connections do
      description("Connections that are critical mass or EOL")

      filter(expr(mass_status == :critical or is_eol == true))
    end

    read :stable_connections do
      description("Stable connections for safe transit")

      filter(expr(mass_status == :stable and is_eol == false))
    end

    read :recent_activity do
      argument :since_hours, :integer do
        default(1)
      end

      filter(expr(last_transit_at > ago(^arg(:since_hours), :hour)))
    end
  end

  calculations do
    calculate :connection_age_hours, :integer do
      description("Hours since connection was discovered")

      calculation(fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.first_discovered_at, :hour)
        end)
      end)
    end

    calculate :minutes_since_transit, :integer do
      description("Minutes since last ship transit")

      calculation(fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          case record.last_transit_at do
            # Never used
            nil -> 9999
            transit_time -> DateTime.diff(now, transit_time, :minute)
          end
        end)
      end)
    end

    calculate :status_summary, :string do
      description("Human-readable status summary")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          mass_text =
            case record.mass_status do
              :stable -> "Stable"
              :destab -> "Destab"
              :critical -> "Critical"
              :unknown -> "Unknown"
            end

          time_text = if record.is_eol, do: "EOL", else: "Stable"

          "#{mass_text}/#{time_text}"
        end)
      end)
    end

    calculate :is_safe_for_capital, :boolean do
      description("Whether connection is safe for capital ships")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          record.mass_status == :stable and not record.is_eol
        end)
      end)
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:update_mass_status, action: :update_mass_status)
    define(:record_transit, action: :record_transit)
    define(:by_chain, action: :by_chain, args: [:chain_topology_id])
    define(:by_system, action: :by_system, args: [:system_id])
    define(:by_signature, action: :by_signature, args: [:signature_id])
    define(:critical_connections, action: :critical_connections)
    define(:stable_connections, action: :stable_connections)
    define(:recent_activity, action: :recent_activity, args: [:since_hours])
  end
end
