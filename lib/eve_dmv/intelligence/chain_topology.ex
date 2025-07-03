defmodule EveDmv.Intelligence.ChainAnalysis.ChainTopology do
  @moduledoc """
  Represents a wormhole chain topology with systems and connections.

  Integrates with Wanderer API to track chain structure, inhabitants,
  and real-time changes for wormhole intelligence.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("chain_topologies")
    repo(EveDmv.Repo)

    custom_indexes do
      index([:map_id], unique: true)
      index([:updated_at])
      index([:corporation_id, :map_id])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :map_id, :string do
      description("Wanderer map identifier (UUID or slug)")
      allow_nil?(false)
    end

    attribute :map_name, :string do
      description("Human-readable map name")
      allow_nil?(true)
    end

    attribute :corporation_id, :integer do
      description("Corporation that owns this chain map")
      allow_nil?(false)
    end

    attribute :alliance_id, :integer do
      description("Alliance that owns this chain map")
      allow_nil?(true)
    end

    attribute :topology_data, :map do
      description("Complete chain topology from Wanderer API")
      allow_nil?(false)
      default(%{})
    end

    attribute :system_count, :integer do
      description("Number of systems in the chain")
      allow_nil?(false)
      default(0)
    end

    attribute :connection_count, :integer do
      description("Number of active connections in the chain")
      allow_nil?(false)
      default(0)
    end

    attribute :last_activity_at, :utc_datetime_usec do
      description("Last time any activity was detected in the chain")
      allow_nil?(true)
    end

    attribute :monitoring_enabled, :boolean do
      description("Whether this chain is actively monitored")
      allow_nil?(false)
      default(true)
    end

    timestamps()
  end

  relationships do
    has_many :system_inhabitants, EveDmv.Intelligence.SystemInhabitant do
      destination_attribute(:chain_topology_id)
    end

    has_many :chain_connections, EveDmv.Intelligence.ChainAnalysis.ChainConnection do
      destination_attribute(:chain_topology_id)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :map_id,
        :map_name,
        :corporation_id,
        :alliance_id,
        :topology_data,
        :system_count,
        :connection_count,
        :monitoring_enabled
      ])

      validate(present([:map_id, :corporation_id]))
    end

    update :update do
      primary?(true)

      accept([
        :map_name,
        :topology_data,
        :system_count,
        :connection_count,
        :last_activity_at,
        :monitoring_enabled
      ])
    end

    update :update_topology do
      description("Update topology data from Wanderer API")
      require_atomic?(false)

      accept([:topology_data, :system_count, :connection_count, :last_activity_at])

      change(fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :updated_at, DateTime.utc_now())
      end)
    end

    update :mark_activity do
      description("Mark chain as having recent activity")
      require_atomic?(false)

      accept([])

      change(fn changeset, _context ->
        Ash.Changeset.force_change_attribute(changeset, :last_activity_at, DateTime.utc_now())
      end)
    end

    read :by_corporation do
      argument :corporation_id, :integer do
        allow_nil?(false)
      end

      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :by_alliance do
      argument :alliance_id, :integer do
        allow_nil?(false)
      end

      filter(expr(alliance_id == ^arg(:alliance_id)))
    end

    read :monitored do
      filter(expr(monitoring_enabled == true))
    end

    read :active do
      description("Chains with recent activity")

      argument :since_hours, :integer do
        default(24)
      end

      filter(
        expr(
          monitoring_enabled == true and
            last_activity_at > ago(^arg(:since_hours), :hour)
        )
      )
    end
  end

  calculations do
    calculate :activity_score, :integer do
      description("Score representing recent activity level")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.last_activity_at do
            nil ->
              0

            activity_time ->
              hours_ago = DateTime.diff(DateTime.utc_now(), activity_time, :hour)
              # Score decreases over 25 hours
              max(0, 100 - hours_ago * 4)
          end
        end)
      end)
    end

    calculate :is_active, :boolean do
      description("Whether chain had activity in last 4 hours")

      calculation(fn records, _context ->
        cutoff = DateTime.add(DateTime.utc_now(), -4, :hour)

        Enum.map(records, fn record ->
          case record.last_activity_at do
            nil -> false
            activity_time -> DateTime.compare(activity_time, cutoff) == :gt
          end
        end)
      end)
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update, action: :update)
    define(:update_topology, action: :update_topology)
    define(:mark_activity, action: :mark_activity)
    define(:by_corporation, action: :by_corporation, args: [:corporation_id])
    define(:by_alliance, action: :by_alliance, args: [:alliance_id])
    define(:monitored, action: :monitored)
    define(:active, action: :active, args: [:since_hours])
  end
end
