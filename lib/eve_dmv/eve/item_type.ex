defmodule EveDmv.Eve.ItemType do
  @moduledoc """
  EVE Online item type reference data resource.

  This resource contains static reference data for all items, ships, modules,
  and other objects in EVE Online. Used for ship/module name lookups and
  fuzzy search capabilities.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("eve_item_types")
    repo(EveDmv.Repo)

    custom_indexes do
      # Primary lookups (removing the one that conflicts with auto-generated primary key)
      index([:type_name], name: "eve_item_types_name_idx")
      index([:group_id], name: "eve_item_types_group_idx")
      index([:category_id], name: "eve_item_types_category_idx")
      index([:market_group_id], name: "eve_item_types_market_group_idx")

      # Fuzzy search with trigram index
      index(["type_name gin_trgm_ops"],
        name: "eve_item_types_name_trgm_idx",
        using: "gin",
        concurrently: false
      )

      # Search by type flags
      index([:published], name: "eve_item_types_published_idx")
      index([:is_ship], name: "eve_item_types_ship_idx")
      index([:is_module], name: "eve_item_types_module_idx")

      # GIN index for search_keywords array
      index([:search_keywords], name: "eve_item_types_search_keywords_gin_idx", using: "gin")
    end
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api)
    define(:read, action: :read)
    define(:create, action: :create)
    define(:get_by_id, args: [:type_id])
    define(:search_by_name, args: [:name_pattern])
    define(:ships_only)
    define(:modules_only)
    define(:by_category, args: [:category_id])
  end

  # Attributes
  attributes do
    # Primary key
    attribute :type_id, :integer do
      allow_nil?(false)
      primary_key?(true)
      description("EVE Online type ID from the Static Data Export (SDE)")
    end

    # Basic item information
    attribute :type_name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
      description("Name of the item type")
    end

    attribute :description, :string do
      allow_nil?(true)
      description("Description text from EVE")
    end

    # Hierarchy information
    attribute :group_id, :integer do
      allow_nil?(true)
      description("EVE group ID this type belongs to")
    end

    attribute :group_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Name of the group")
    end

    attribute :category_id, :integer do
      allow_nil?(true)
      description("EVE category ID this type belongs to")
    end

    attribute :category_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Name of the category")
    end

    # Market information
    attribute :market_group_id, :integer do
      allow_nil?(true)
      description("Market group ID for market browser hierarchy")
    end

    attribute :market_group_name, :string do
      allow_nil?(true)
      constraints(max_length: 255)
      description("Name of the market group")
    end

    # Physical properties
    attribute :mass, :decimal do
      allow_nil?(true)
      constraints(precision: 15, scale: 4)
      description("Mass of the item in kg")
    end

    attribute :volume, :decimal do
      allow_nil?(true)
      constraints(precision: 15, scale: 4)
      description("Volume of the item in m³")
    end

    attribute :capacity, :decimal do
      allow_nil?(true)
      constraints(precision: 15, scale: 4)
      description("Cargo/drone bay capacity in m³")
    end

    # Attributes for ships
    attribute :base_price, :decimal do
      allow_nil?(true)
      constraints(precision: 15, scale: 2)
      description("Base NPC price in ISK")
    end

    # Meta information
    attribute :meta_level, :integer do
      allow_nil?(true)
      description("Meta level of the item (0-15+)")
    end

    attribute :tech_level, :integer do
      allow_nil?(true)
      description("Tech level (1=T1, 2=T2, 3=T3)")
    end

    # Classification flags
    attribute :published, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether this item is published/available in game")
    end

    attribute :is_ship, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether this item is a ship")
    end

    attribute :is_module, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether this item is a fittable module")
    end

    attribute :is_charge, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether this item is ammunition/charges")
    end

    attribute :is_blueprint, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether this item is a blueprint")
    end

    attribute :is_deployable, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether this item can be deployed in space")
    end

    # Search metadata
    attribute :search_keywords, {:array, :string} do
      allow_nil?(true)
      default([])
      description("Additional keywords for search (abbreviations, common names, etc.)")
    end

    # SDE metadata
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
    identity :type_id, [:type_id] do
      description("Unique EVE type ID for upserts")
    end
  end

  # Actions
  actions do
    # Default actions
    defaults([:read, :update, :destroy])

    # Custom create/upsert for SDE imports
    create :create do
      primary?(true)
      description("Create or update item type from SDE")

      accept([
        :type_id,
        :type_name,
        :description,
        :group_id,
        :group_name,
        :category_id,
        :category_name,
        :market_group_id,
        :market_group_name,
        :mass,
        :volume,
        :capacity,
        :base_price,
        :meta_level,
        :tech_level,
        :published,
        :is_ship,
        :is_module,
        :is_charge,
        :is_blueprint,
        :is_deployable,
        :search_keywords,
        :sde_version
      ])

      # Upsert for SDE updates
      upsert?(true)
      upsert_identity(:type_id)

      change(set_attribute(:last_updated, &DateTime.utc_now/0))
    end

    # Read actions for specific queries
    read :get_by_id do
      description("Get item type by EVE type ID")

      argument :type_id, :integer do
        allow_nil?(false)
        description("EVE type ID to look up")
      end

      get?(true)
      filter(expr(type_id == ^arg(:type_id)))
    end

    read :search_by_name do
      description("Fuzzy search item types by name using trigram matching")

      argument :name_pattern, :string do
        allow_nil?(false)
        constraints(min_length: 2)
        description("Search pattern (partial name)")
      end

      # Use PostgreSQL trigram similarity for fuzzy matching
      filter(expr(fragment("similarity(type_name, ?) > 0.3", ^arg(:name_pattern))))
      prepare(build(sort: [:type_name]))
    end

    read :exact_name_search do
      description("Search for exact name matches (case insensitive)")

      argument :type_name, :string do
        allow_nil?(false)
        description("Exact type name to search for")
      end

      filter(expr(fragment("lower(type_name) = lower(?)", ^arg(:type_name))))
    end

    read :ships_only do
      description("Get only ship types")

      filter(expr(is_ship == true and published == true))
      prepare(build(sort: [:type_name]))
    end

    read :modules_only do
      description("Get only module types")

      filter(expr(is_module == true and published == true))
      prepare(build(sort: [:type_name]))
    end

    read :by_category do
      description("Get item types by category")

      argument :category_id, :integer do
        allow_nil?(false)
        description("Category ID to filter by")
      end

      filter(expr(category_id == ^arg(:category_id) and published == true))
      prepare(build(sort: [:group_name, :type_name]))
    end

    read :by_group do
      description("Get item types by group")

      argument :group_id, :integer do
        allow_nil?(false)
        description("Group ID to filter by")
      end

      filter(expr(group_id == ^arg(:group_id) and published == true))
      prepare(build(sort: [:type_name]))
    end

    read :by_market_group do
      description("Get item types by market group")

      argument :market_group_id, :integer do
        allow_nil?(false)
        description("Market group ID to filter by")
      end

      filter(expr(market_group_id == ^arg(:market_group_id) and published == true))
      prepare(build(sort: [:type_name]))
    end

    read :high_meta do
      description("Get high meta level items")

      argument :min_meta_level, :integer do
        allow_nil?(false)
        default(5)
        description("Minimum meta level")
      end

      filter(expr(meta_level >= ^arg(:min_meta_level) and published == true))
      prepare(build(sort: [:meta_level, :type_name]))
    end

    read :tech2_items do
      description("Get Tech 2 items")

      filter(expr(tech_level == 2 and published == true))
      prepare(build(sort: [:category_name, :group_name, :type_name]))
    end
  end

  # Relationships (for future expansion)
  relationships do
    # Note: Relationships removed for now
    # Will be implemented using manual queries in Epic 2
  end

  # Calculations
  calculations do
    calculate :is_expensive_ship, :boolean, expr(is_ship and base_price > 100_000_000) do
      description("Whether this is an expensive ship (>100M ISK base price)")
    end

    calculate :is_capital_ship,
              :boolean,
              expr(
                is_ship and
                  category_name in [
                    "Dreadnought",
                    "Carrier",
                    "Supercarrier",
                    "Titan",
                    "Capital Industrial Ship"
                  ]
              ) do
      description("Whether this is a capital ship")
    end

    calculate :size_category, :string do
      description("Size category based on volume/mass")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          cond do
            record.is_ship and record.mass && record.mass > 1_000_000_000 -> "capital"
            record.is_ship and record.mass && record.mass > 100_000_000 -> "battleship"
            record.is_ship and record.mass && record.mass > 10_000_000 -> "cruiser"
            record.is_ship and record.mass && record.mass > 1_000_000 -> "frigate"
            record.is_ship -> "unknown"
            true -> "item"
          end
        end)
      end)
    end
  end

  # Aggregates
  aggregates do
    # Note: Aggregates removed for now due to missing relationships
    # Will be re-added in Epic 2 with manual queries
  end

  # Authorization policies
  policies do
    # Public read access for all EVE data
    policy action_type(:read) do
      authorize_if(always())
    end

    # Only authenticated admin users can modify item type data
    policy action_type([:create, :update, :destroy]) do
      authorize_if(actor_attribute_equals(:is_admin, true))
    end
  end
end
