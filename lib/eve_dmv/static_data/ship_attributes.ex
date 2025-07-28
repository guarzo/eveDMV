defmodule EveDmv.StaticData.ShipAttributes do
  @moduledoc """
  Ship attributes resource for comprehensive ship performance data.

  This resource stores calculated ship attributes including DPS, EHP, resistances,
  and tactical classifications derived from EVE SDE dogma data.

  Used by fleet analysis to replace hardcoded values with real ship performance metrics.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("ship_attributes")
    repo(EveDmv.Repo)
  end

  # Resource configuration
  code_interface do
    domain(EveDmv.Api)
    define(:get_by_type_id, args: [:type_id])
    define(:list_by_role, args: [:role_classification])
    define(:list_by_size_class, args: [:size_class])
  end

  # Attributes
  attributes do
    attribute :type_id, :integer do
      allow_nil?(false)
      primary_key?(true)
      description("EVE item type ID")
    end

    # Defense attributes
    attribute :shield_hp, :integer do
      allow_nil?(true)
      description("Shield hit points")
    end

    attribute :armor_hp, :integer do
      allow_nil?(true)
      description("Armor hit points")
    end

    attribute :structure_hp, :integer do
      allow_nil?(true)
      description("Structure hit points")
    end

    # Shield resistances
    attribute :shield_em_resist, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Shield EM damage resistance (0.0-1.0)")
    end

    attribute :shield_thermal_resist, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Shield thermal damage resistance (0.0-1.0)")
    end

    attribute :shield_kinetic_resist, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Shield kinetic damage resistance (0.0-1.0)")
    end

    attribute :shield_explosive_resist, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Shield explosive damage resistance (0.0-1.0)")
    end

    # Armor resistances
    attribute :armor_em_resist, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Armor EM damage resistance (0.0-1.0)")
    end

    attribute :armor_thermal_resist, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Armor thermal damage resistance (0.0-1.0)")
    end

    attribute :armor_kinetic_resist, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Armor kinetic damage resistance (0.0-1.0)")
    end

    attribute :armor_explosive_resist, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Armor explosive damage resistance (0.0-1.0)")
    end

    # Calculated performance metrics
    attribute :calculated_dps, :decimal do
      allow_nil?(true)
      constraints(min: 0.0)
      description("Estimated DPS output")
    end

    attribute :calculated_ehp, :decimal do
      allow_nil?(true)
      constraints(min: 0.0)
      description("Effective hit points (worst case resistance)")
    end

    attribute :calculated_ehp_uniform, :decimal do
      allow_nil?(true)
      constraints(min: 0.0)
      description("EHP against uniform damage distribution")
    end

    # Classification attributes
    attribute :role_classification, :string do
      allow_nil?(true)
      description("Primary tactical role")
    end

    attribute :size_class, :string do
      allow_nil?(true)
      description("Ship size classification")
    end

    attribute :tactical_category, :string do
      allow_nil?(true)
      description("Tactical usage category")
    end

    # Performance ratings (0.0-1.0)
    attribute :damage_rating, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Relative damage output rating")
    end

    attribute :tank_rating, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Relative tank strength rating")
    end

    attribute :speed_rating, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Relative speed/agility rating")
    end

    attribute :utility_rating, :decimal do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Relative utility/support rating")
    end

    # Metadata
    attribute :data_source, :string do
      allow_nil?(false)
      default("sde_import")
      description("Source of attribute data")
    end

    attribute :confidence_score, :decimal do
      allow_nil?(false)
      default(0.5)
      constraints(min: 0.0, max: 1.0)
      description("Data quality confidence score")
    end

    attribute :last_updated, :utc_datetime do
      allow_nil?(true)
      description("When attributes were last calculated")
    end

    timestamps()
  end

  # Relationships
  relationships do
    belongs_to :ship_type, EveDmv.Eve.ItemType do
      source_attribute(:type_id)
      destination_attribute(:type_id)
      description("Ship type information")
    end
  end

  # Actions
  actions do
    defaults([:read])

    create :create do
      primary?(true)
      description("Create ship attributes record")

      accept([
        :type_id,
        :shield_hp,
        :armor_hp,
        :structure_hp,
        :shield_em_resist,
        :shield_thermal_resist,
        :shield_kinetic_resist,
        :shield_explosive_resist,
        :armor_em_resist,
        :armor_thermal_resist,
        :armor_kinetic_resist,
        :armor_explosive_resist,
        :calculated_dps,
        :calculated_ehp,
        :calculated_ehp_uniform,
        :role_classification,
        :size_class,
        :tactical_category,
        :damage_rating,
        :tank_rating,
        :speed_rating,
        :utility_rating,
        :data_source,
        :confidence_score,
        :last_updated
      ])

      upsert?(true)
      upsert_identity(:type_id)
    end

    update :update do
      primary?(true)
      description("Update ship attributes")

      accept([
        :shield_hp,
        :armor_hp,
        :structure_hp,
        :shield_em_resist,
        :shield_thermal_resist,
        :shield_kinetic_resist,
        :shield_explosive_resist,
        :armor_em_resist,
        :armor_thermal_resist,
        :armor_kinetic_resist,
        :armor_explosive_resist,
        :calculated_dps,
        :calculated_ehp,
        :calculated_ehp_uniform,
        :role_classification,
        :size_class,
        :tactical_category,
        :damage_rating,
        :tank_rating,
        :speed_rating,
        :utility_rating,
        :data_source,
        :confidence_score,
        :last_updated
      ])
    end

    read :get_by_type_id do
      description("Get ship attributes by type ID")

      argument :type_id, :integer do
        allow_nil?(false)
        description("Ship type ID")
      end

      filter(expr(type_id == ^arg(:type_id)))
    end

    read :list_by_role do
      description("List ships by tactical role")

      argument :role_classification, :string do
        allow_nil?(false)
        description("Tactical role to filter by")
      end

      filter(expr(role_classification == ^arg(:role_classification)))
      prepare(build(sort: [calculated_dps: :desc]))
    end

    read :list_by_size_class do
      description("List ships by size class")

      argument :size_class, :string do
        allow_nil?(false)
        description("Size class to filter by")
      end

      filter(expr(size_class == ^arg(:size_class)))
      prepare(build(sort: [calculated_ehp: :desc]))
    end

    read :high_dps_ships do
      description("Get ships with high DPS ratings")

      argument :min_dps, :decimal do
        allow_nil?(false)
        default(500.0)
        description("Minimum DPS threshold")
      end

      filter(expr(calculated_dps >= ^arg(:min_dps)))
      prepare(build(sort: [calculated_dps: :desc]))
    end

    read :tank_ships do
      description("Get ships optimized for tanking")

      argument :min_ehp, :decimal do
        allow_nil?(false)
        default(50000.0)
        description("Minimum EHP threshold")
      end

      filter(expr(calculated_ehp >= ^arg(:min_ehp)))
      prepare(build(sort: [calculated_ehp: :desc]))
    end
  end

  # Calculations for fleet analysis
  calculations do
    calculate :total_ehp, :decimal do
      description("Total EHP including all layers")

      calculation(
        expr(coalesce(shield_hp, 0) + coalesce(armor_hp, 0) + coalesce(structure_hp, 0))
      )
    end

    calculate :worst_resist, :decimal do
      description("Worst case resistance across all damage types")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          resistances = [
            record.shield_em_resist || 0.0,
            record.shield_thermal_resist || 0.0,
            record.shield_kinetic_resist || 0.0,
            record.shield_explosive_resist || 0.0,
            record.armor_em_resist || 0.0,
            record.armor_thermal_resist || 0.0,
            record.armor_kinetic_resist || 0.0,
            record.armor_explosive_resist || 0.0
          ]

          Enum.min(resistances, fn -> 0.0 end)
        end)
      end)
    end

    calculate :dps_per_ehp_ratio, :decimal do
      description("DPS to EHP ratio for effectiveness comparison")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          dps = record.calculated_dps || 0.0
          ehp = record.calculated_ehp || 1.0
          if ehp > 0, do: Float.round(dps / (ehp / 1000), 3), else: 0.0
        end)
      end)
    end

    calculate :effectiveness_score, :decimal do
      description("Composite effectiveness score")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          damage = record.damage_rating || 0.0
          tank = record.tank_rating || 0.0
          speed = record.speed_rating || 0.0
          utility = record.utility_rating || 0.0

          # Weighted effectiveness: 40% damage, 30% tank, 20% speed, 10% utility
          Float.round(damage * 0.4 + tank * 0.3 + speed * 0.2 + utility * 0.1, 3)
        end)
      end)
    end
  end

  # Authorization policies
  policies do
    # Public read access for ship attribute data
    policy action_type(:read) do
      authorize_if(always())
    end

    # Restrict write access to admin users
    policy action_type([:create, :update, :destroy]) do
      authorize_if(actor_attribute_equals(:is_admin, true))
    end
  end

  # Identities
  identities do
    identity :type_id, [:type_id] do
      description("Each ship type has unique attributes")
    end
  end
end
