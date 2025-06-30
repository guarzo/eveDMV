defmodule EveDmv.Eve.SolarSystem do
  @moduledoc """
  EVE Online solar system reference data resource.

  This resource contains static reference data for all solar systems in EVE Online.
  Used for system name lookups and location-based filtering.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("eve_solar_systems")
    repo(EveDmv.Repo)

    custom_indexes do
      # Primary lookups
      index([:system_name], name: "eve_solar_systems_name_idx")
      index([:region_id], name: "eve_solar_systems_region_idx")
      index([:constellation_id], name: "eve_solar_systems_constellation_idx")
      index([:security_status], name: "eve_solar_systems_security_idx")

      # Fuzzy search with trigram index
      index(["system_name gin_trgm_ops"],
        name: "eve_solar_systems_name_trgm_idx",
        using: "gin",
        concurrently: false
      )
    end
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api)
    define(:read, action: :read)
    define(:create, action: :create)
    define(:get_by_id, args: [:system_id])
    define(:search_by_name, args: [:name_pattern])
    define(:by_security_class, args: [:security_class])
  end

  # Attributes
  attributes do
    # Primary key
    attribute :system_id, :integer do
      allow_nil?(false)
      primary_key?(true)
      description("EVE Online solar system ID from the Static Data Export (SDE)")
    end

    # Basic system information
    attribute :system_name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
      description("Name of the solar system")
    end

    # Hierarchy information
    attribute :region_id, :integer do
      allow_nil?(true)
      description("EVE region ID this system belongs to")
    end

    attribute :region_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Name of the region")
    end

    attribute :constellation_id, :integer do
      allow_nil?(true)
      description("EVE constellation ID this system belongs to")
    end

    attribute :constellation_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Name of the constellation")
    end

    # Security information
    attribute :security_status, :decimal do
      allow_nil?(true)
      constraints(precision: 15, scale: 10)
      description("Security status (-1.0 to 1.0)")
    end

    attribute :security_class, :string do
      allow_nil?(true)
      constraints(max_length: 20)
      description("Security class (highsec, lowsec, nullsec, wormhole)")
    end

    # Physical properties
    attribute :x, :decimal do
      allow_nil?(true)
      constraints(precision: 25, scale: 2)
      description("X coordinate in universe")
    end

    attribute :y, :decimal do
      allow_nil?(true)
      constraints(precision: 25, scale: 2)
      description("Y coordinate in universe")
    end

    attribute :z, :decimal do
      allow_nil?(true)
      constraints(precision: 25, scale: 2)
      description("Z coordinate in universe")
    end

    # Metadata
    attribute :sde_version, :string do
      allow_nil?(true)
      constraints(max_length: 50)
      description("Version of the SDE this data came from")
    end

    attribute :last_updated, :utc_datetime do
      allow_nil?(true)
      description("When this record was last updated from SDE")
    end

    # Automatic timestamps
    timestamps()
  end

  # Identities for uniqueness constraints
  identities do
    identity :system_id, [:system_id] do
      description("Unique EVE system ID for upserts")
    end
  end

  # Actions
  actions do
    # Default actions
    defaults([:read, :update, :destroy])

    # Custom create/upsert for SDE imports
    create :create do
      description("Create or update solar system from SDE")

      accept([
        :system_id,
        :system_name,
        :region_id,
        :region_name,
        :constellation_id,
        :constellation_name,
        :security_status,
        :security_class,
        :x,
        :y,
        :z,
        :sde_version
      ])

      # Upsert for SDE updates
      upsert?(true)
      upsert_identity(:system_id)

      change(set_attribute(:last_updated, &DateTime.utc_now/0))
    end

    # Read actions for specific queries
    read :get_by_id do
      description("Get solar system by EVE system ID")

      argument :system_id, :integer do
        allow_nil?(false)
        description("EVE system ID to look up")
      end

      get?(true)
      filter(expr(system_id == ^arg(:system_id)))
    end

    read :search_by_name do
      description("Fuzzy search solar systems by name using trigram matching")

      argument :name_pattern, :string do
        allow_nil?(false)
        constraints(min_length: 2)
        description("Search pattern (partial system name)")
      end

      argument :similarity_threshold, :float do
        allow_nil?(true)
        default(0.3)
        constraints(min: 0.0, max: 1.0)
        description("Minimum similarity score (0.0-1.0, default: 0.3)")
      end

      # Use PostgreSQL trigram similarity for fuzzy matching
      filter(
        expr(
          fragment(
            "similarity(system_name, ?) > ?",
            ^arg(:name_pattern),
            ^arg(:similarity_threshold)
          )
        )
      )

      prepare(build(sort: [:system_name]))
    end

    read :by_security_class do
      description("Get systems by security class")

      argument :security_class, :string do
        allow_nil?(false)
        description("Security class (highsec, lowsec, nullsec, wormhole)")
      end

      filter(expr(security_class == ^arg(:security_class)))
      prepare(build(sort: [:system_name]))
    end

    read :by_region do
      description("Get systems by region")

      argument :region_id, :integer do
        allow_nil?(false)
        description("Region ID to filter by")
      end

      filter(expr(region_id == ^arg(:region_id)))
      prepare(build(sort: [:system_name]))
    end
  end

  # Calculations
  calculations do
    calculate :is_highsec, :boolean, expr(security_status >= 0.45) do
      description("Whether this is a high security system")
    end

    calculate :is_lowsec, :boolean, expr(security_status >= 0.05 and security_status < 0.45) do
      description("Whether this is a low security system")
    end

    calculate :is_nullsec, :boolean, expr(security_status < 0.05) do
      description("Whether this is a null security system")
    end
  end

  # Authorization policies
  policies do
    # Public read access for all EVE data
    policy action_type(:read) do
      authorize_if(always())
    end

    # Only authenticated admins can modify system data
    policy action_type([:create, :update, :destroy]) do
      # For now, allow all authenticated users
      # In production, this would be admin-only
      authorize_if(actor_present())
    end
  end
end
