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

    # Wormhole-specific information
    attribute :wormhole_class_id, :integer do
      allow_nil?(true)
      description("Wormhole class ID (1-25) for wormhole systems")
    end

    attribute :wormhole_effect_type, :string do
      allow_nil?(true)
      constraints(max_length: 50)
      description("Wormhole environmental effect type (Pulsar, Black Hole, Magnetar, etc.)")
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
        :wormhole_class_id,
        :wormhole_effect_type,
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

    # Custom update action for wormhole data
    update :update_wormhole_data do
      description("Update solar system with wormhole class information")
      
      accept([:wormhole_class_id, :wormhole_effect_type])
      
      change(set_attribute(:last_updated, &DateTime.utc_now/0))
    end

    # Custom update action for SDE version tracking
    update :update_sde_version do
      description("Update solar system with SDE version information")
      
      accept([:sde_version, :last_updated])
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

    calculate :is_wormhole, :boolean, expr(security_class == "wormhole") do
      description("Whether this is a wormhole system")
    end

    calculate :wormhole_class_name, :string, expr(
      cond do
        wormhole_class_id == 1 -> "C1"
        wormhole_class_id == 2 -> "C2"
        wormhole_class_id == 3 -> "C3"
        wormhole_class_id == 4 -> "C4"
        wormhole_class_id == 5 -> "C5"
        wormhole_class_id == 6 -> "C6"
        wormhole_class_id == 7 -> "High-Sec"
        wormhole_class_id == 8 -> "Low-Sec"
        wormhole_class_id == 9 -> "Null-Sec"
        wormhole_class_id == 12 -> "Thera"
        wormhole_class_id == 13 -> "Shattered"
        wormhole_class_id == 14 -> "Sentinel"
        wormhole_class_id == 15 -> "Barbican"
        wormhole_class_id == 16 -> "Vidette"
        wormhole_class_id == 17 -> "Conflux"
        wormhole_class_id == 18 -> "Redoubt"
        true -> "Unknown"
      end
    ) do
      description("Human-readable wormhole class name")
    end

    calculate :has_wormhole_effect, :boolean, expr(
      is_not_nil(wormhole_effect_type) and wormhole_effect_type != ""
    ) do
      description("Whether this system has a wormhole environmental effect")
    end

    calculate :wormhole_effect_description, :string, expr(
      cond do
        wormhole_effect_type == "Pulsar" -> "Boosts shield capacity and capacitor recharge, reduces armor resists"
        wormhole_effect_type == "Black Hole" -> "Increases missile velocity, ship velocity, and targeting range"
        wormhole_effect_type == "Cataclysmic Variable" -> "Enhances remote repair modules and capacitor volume"
        wormhole_effect_type == "Magnetar" -> "Dramatically increases weapon damage, reduces tracking"
        wormhole_effect_type == "Red Giant" -> "Boosts smartbomb damage, range, and module overheat effects"
        wormhole_effect_type == "Wolf Rayet" -> "Enhances armor HP and small weapon damage, reduces shield resists"
        true -> "No environmental effect"
      end
    ) do
      description("Description of the wormhole environmental effect")
    end
  end

  # Authorization policies
  policies do
    # Public read access for all EVE data
    policy action_type(:read) do
      authorize_if(always())
    end

    # Only authenticated admin users can modify system data
    policy action_type([:create, :update, :destroy]) do
      authorize_if(actor_attribute_equals(:is_admin, true))
    end
  end
end
