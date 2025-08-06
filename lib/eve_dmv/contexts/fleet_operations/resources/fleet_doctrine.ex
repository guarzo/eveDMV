defmodule EveDmv.Contexts.FleetOperations.Resources.FleetDoctrine do
  @moduledoc """
  Fleet doctrine resource for storing and managing fleet compositions.

  Doctrines define standard fleet setups including ship requirements,
  role distributions, and operational parameters.
  """

  use Ash.Resource,
    otp_app: :eve_dmv,
    domain: EveDmv.Contexts.FleetOperations.Domain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("fleet_doctrines")
    repo(EveDmv.Repo)
  end

  code_interface do
    domain(EveDmv.Contexts.FleetOperations.Domain)
  end

  attributes do
    uuid_primary_key(:id)

    attribute :name, :string do
      allow_nil?(false)
      constraints(max_length: 255)
      description("Name of the doctrine")
    end

    attribute :description, :string do
      allow_nil?(true)
      constraints(max_length: 2000)
      description("Detailed description of the doctrine")
    end

    attribute :doctrine_type, :atom do
      allow_nil?(false)
      default(:roam)
      constraints(one_of: [:roam, :home_defense, :structure_bash, :capital, :black_ops])
      description("Type of fleet doctrine")
    end

    attribute :ship_requirements, :map do
      allow_nil?(false)
      default(%{})
      description("Map of ship_type_id to requirement details {min_count, max_count, priority}")
    end

    attribute :role_requirements, :map do
      allow_nil?(false)
      default(%{})
      description("Map of role to requirement details {min_count, max_count, priority}")
    end

    attribute :optional_ships, {:array, :integer} do
      allow_nil?(false)
      default([])
      description("List of optional ship type IDs")
    end

    attribute :mass_limits, :map do
      allow_nil?(false)
      default(%{})
      description("Mass constraints for wormhole operations")
    end

    attribute :mass_category, :atom do
      allow_nil?(false)
      default(:medium)
      constraints(one_of: [:light, :medium, :heavy, :capital])
      description("Overall mass category of the doctrine")
    end

    attribute :minimum_pilots, :integer do
      allow_nil?(false)
      default(5)
      constraints(min: 1)
      description("Minimum number of pilots for this doctrine")
    end

    attribute :optimal_pilots, :integer do
      allow_nil?(true)
      constraints(min: 1)
      description("Optimal number of pilots for effectiveness")
    end

    attribute :corporation_id, :integer do
      allow_nil?(true)
      description("Corporation that owns this doctrine (null for public)")
    end

    attribute :is_active, :boolean do
      allow_nil?(false)
      default(true)
      description("Whether the doctrine is currently active")
    end

    attribute :is_public, :boolean do
      allow_nil?(false)
      default(false)
      description("Whether the doctrine is publicly visible")
    end

    attribute :created_by, :integer do
      allow_nil?(false)
      description("Character ID who created the doctrine")
    end

    attribute :usage_count, :integer do
      allow_nil?(false)
      default(0)
      description("Number of times this doctrine has been used")
    end

    attribute :effectiveness_rating, :float do
      allow_nil?(true)
      constraints(min: 0.0, max: 1.0)
      description("Calculated effectiveness based on fleet performance")
    end

    attribute :tags, {:array, :string} do
      allow_nil?(false)
      default([])
      description("Tags for categorization and search")
    end

    attribute :fitting_notes, :string do
      allow_nil?(true)
      constraints(max_length: 5000)
      description("Notes about recommended fittings")
    end

    create_timestamp(:created_at)
    update_timestamp(:updated_at)

    attribute :last_used_at, :utc_datetime do
      allow_nil?(true)
      description("When this doctrine was last used in a fleet")
    end
  end

  identities do
    identity :unique_name_per_corp, [:name, :corporation_id] do
      description("Doctrine names must be unique within a corporation")
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :name,
        :description,
        :doctrine_type,
        :ship_requirements,
        :role_requirements,
        :optional_ships,
        :mass_limits,
        :mass_category,
        :minimum_pilots,
        :optimal_pilots,
        :corporation_id,
        :is_active,
        :is_public,
        :created_by,
        :tags,
        :fitting_notes
      ])

      change(fn changeset, _ ->
        # Calculate mass category based on ship requirements
        ship_requirements = Ash.Changeset.get_attribute(changeset, :ship_requirements)
        mass_category = calculate_mass_category(ship_requirements)
        Ash.Changeset.change_attribute(changeset, :mass_category, mass_category)
      end)
    end

    update :update do
      primary?(true)
      require_atomic?(false)

      accept([
        :name,
        :description,
        :doctrine_type,
        :ship_requirements,
        :role_requirements,
        :optional_ships,
        :mass_limits,
        :minimum_pilots,
        :optimal_pilots,
        :is_active,
        :is_public,
        :tags,
        :fitting_notes
      ])

      change(fn changeset, _ ->
        # Recalculate mass category if ships changed
        if Ash.Changeset.changing_attribute?(changeset, :ship_requirements) do
          ship_requirements = Ash.Changeset.get_attribute(changeset, :ship_requirements)
          mass_category = calculate_mass_category(ship_requirements)
          Ash.Changeset.change_attribute(changeset, :mass_category, mass_category)
        else
          changeset
        end
      end)
    end

    read :by_id do
      get?(true)

      argument :id, :uuid do
        allow_nil?(false)
      end

      filter(expr(id == ^arg(:id)))
    end

    read :by_corporation do
      argument :corporation_id, :integer do
        allow_nil?(false)
      end

      filter(expr(corporation_id == ^arg(:corporation_id) or is_public == true))
    end

    read :active do
      filter(expr(is_active == true))
    end

    read :by_type do
      argument :doctrine_type, :atom do
        allow_nil?(false)
      end

      filter(expr(doctrine_type == ^arg(:doctrine_type) and is_active == true))
    end

    read :search do
      argument :query, :string do
        allow_nil?(false)
      end

      filter(
        expr(
          contains(name, ^arg(:query)) or
            contains(description, ^arg(:query)) or
            ^arg(:query) in tags
        )
      )
    end

    update :increment_usage do
      require_atomic?(false)

      change(fn changeset, _ ->
        current_count = changeset.data.usage_count || 0

        changeset
        |> Ash.Changeset.change_attribute(:usage_count, current_count + 1)
        |> Ash.Changeset.change_attribute(:last_used_at, DateTime.utc_now())
      end)
    end

    update :update_effectiveness do
      argument :rating, :float do
        allow_nil?(false)
        constraints(min: 0.0, max: 1.0)
      end

      change(set_attribute(:effectiveness_rating, arg(:rating)))
    end
  end

  calculations do
    calculate :total_minimum_pilots, :integer do
      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          ship_mins =
            record.ship_requirements
            |> Map.values()
            |> Enum.map(&Map.get(&1, "min_count", 0))
            |> Enum.sum()

          role_mins =
            record.role_requirements
            |> Map.values()
            |> Enum.map(&Map.get(&1, "min_count", 0))
            |> Enum.sum()

          max(ship_mins, role_mins)
        end)
      end)
    end

    calculate :completeness_score, :float do
      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          # Score based on how well-defined the doctrine is
          ship_score = if map_size(record.ship_requirements) > 0, do: 0.25, else: 0
          role_score = if map_size(record.role_requirements) > 0, do: 0.25, else: 0

          desc_score =
            if record.description && String.length(record.description) > 50, do: 0.2, else: 0

          fitting_score =
            if record.fitting_notes && String.length(record.fitting_notes) > 100, do: 0.2, else: 0

          effectiveness_score = if record.effectiveness_rating, do: 0.1, else: 0

          ship_score + role_score + desc_score + fitting_score + effectiveness_score
        end)
      end)
    end
  end

  policies do
    policy action_type(:read) do
      # Anyone can read public doctrines
      authorize_if(expr(is_public == true))

      # Members can read their corp's doctrines
      authorize_if(expr(corporation_id == ^actor(:corporation_id)))

      # Creators can read their own doctrines
      authorize_if(expr(created_by == ^actor(:character_id)))
    end

    policy action_type(:create) do
      # Must be authenticated
      authorize_if(actor_present())
    end

    policy action_type([:update, :destroy]) do
      # Creators can modify their own doctrines
      authorize_if(expr(created_by == ^actor(:character_id)))

      # Corp directors can modify corp doctrines
      authorize_if(
        expr(
          corporation_id == ^actor(:corporation_id) and
            ^actor(:has_director_role) == true
        )
      )
    end
  end

  defp calculate_mass_category(ship_requirements) when is_map(ship_requirements) do
    # Estimate total mass based on ship requirements
    total_mass =
      ship_requirements
      |> Enum.map(fn {ship_type_id, req} ->
        min_count = Map.get(req, "min_count", 0)
        ship_mass = get_ship_mass(ship_type_id)
        ship_mass * min_count
      end)
      |> Enum.sum()

    cond do
      total_mass < 100_000_000 -> :light
      total_mass < 500_000_000 -> :medium
      total_mass < 1_500_000_000 -> :heavy
      true -> :capital
    end
  end

  defp calculate_mass_category(_), do: :medium

  defp get_ship_mass(ship_type_id) when is_binary(ship_type_id) do
    case Integer.parse(ship_type_id) do
      {id, _} -> get_ship_mass(id)
      _ -> 10_000_000
    end
  end

  defp get_ship_mass(ship_type_id) when is_integer(ship_type_id) do
    # Use the DoctrineManager's get_ship_mass function
    EveDmv.Contexts.FleetOperations.Domain.DoctrineManager.get_ship_mass(ship_type_id)
  end

  defp get_ship_mass(_), do: 10_000_000
end
