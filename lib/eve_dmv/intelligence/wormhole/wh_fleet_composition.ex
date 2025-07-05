defmodule EveDmv.Intelligence.Wormhole.FleetComposition do
  @moduledoc """
  Wormhole fleet composition analysis and optimization tools.

  Provides fleet doctrine templates, mass calculations, skill gap analysis,
  and ship availability tracking specifically designed for wormhole operations.
  """

  use Ash.Resource,
    domain: EveDmv.Api,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("wh_fleet_composition")
    repo(EveDmv.Repo)

    custom_indexes do
      # Optimize common lookups
      index([:corporation_id])
      index([:alliance_id])
      index([:doctrine_name])
      index([:fleet_size_category])
      index([:last_updated_at])

      # GIN indexes for JSONB columns
      index([:doctrine_template], name: "wh_fleet_doctrine_template_gin_idx", using: "gin")
      index([:ship_requirements], name: "wh_fleet_ship_requirements_gin_idx", using: "gin")
      index([:pilot_assignments], name: "wh_fleet_pilot_assignments_gin_idx", using: "gin")
      index([:skill_gaps], name: "wh_fleet_skill_gaps_gin_idx", using: "gin")
      index([:mass_calculations], name: "wh_fleet_mass_calculations_gin_idx", using: "gin")
      index([:optimization_results], name: "wh_fleet_optimization_gin_idx", using: "gin")
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Fleet identification
    attribute(:corporation_id, :integer, allow_nil?: false, public?: true)
    attribute(:corporation_name, :string, allow_nil?: false, public?: true)
    attribute(:alliance_id, :integer, public?: true)
    attribute(:alliance_name, :string, public?: true)

    # Doctrine information
    attribute(:doctrine_name, :string, allow_nil?: false, public?: true)
    attribute(:doctrine_description, :string, public?: true)
    # small, medium, large
    attribute(:fleet_size_category, :string, allow_nil?: false, public?: true)
    attribute(:minimum_pilots, :integer, default: 1, public?: true)
    attribute(:optimal_pilots, :integer, default: 5, public?: true)
    attribute(:maximum_pilots, :integer, default: 10, public?: true)

    # Fleet metadata
    # Character ID
    attribute(:created_by, :integer, public?: true)
    attribute(:last_updated_at, :utc_datetime, default: &DateTime.utc_now/0, public?: true)
    # 0.0-1.0
    attribute(:effectiveness_rating, :float, default: 0.0, public?: true)
    attribute(:usage_count, :integer, default: 0, public?: true)
    # 0.0-1.0
    attribute(:success_rate, :float, default: 0.0, public?: true)

    # Doctrine template (JSONB)
    attribute(:doctrine_template, :map, default: %{}, public?: true)
    # Format: %{
    #   "fleet_commander" => %{
    #     "required" => 1,
    #     "preferred_ships" => ["Command Ship", "Battlecruiser"],
    #     "skills_required" => ["Leadership V", "Fleet Command IV"],
    #     "priority" => 1
    #   },
    #   "logistics" => %{
    #     "required" => 2,
    #     "preferred_ships" => ["Guardian", "Basilisk"],
    #     "skills_required" => ["Logistics V", "Capacitor Management IV"],
    #     "priority" => 2
    #   },
    #   "tackle" => %{
    #     "required" => 2,
    #     "preferred_ships" => ["Interceptor", "Heavy Interdictor"],
    #     "skills_required" => ["Interceptors V", "Warp Disruption IV"],
    #     "priority" => 3
    #   },
    #   "dps" => %{
    #     "required" => 4,
    #     "preferred_ships" => ["HAC", "T3 Cruiser", "Assault Frigate"],
    #     "skills_required" => ["HAC IV", "T3 Cruiser IV"],
    #     "priority" => 4
    #   }
    # }

    # Ship requirements and availability (JSONB)
    attribute(:ship_requirements, :map, default: %{}, public?: true)
    # Format: %{
    #   "587" => %{  # Rifter type_id
    #     "ship_name" => "Rifter",
    #     "role" => "tackle",
    #     "quantity_needed" => 2,
    #     "quantity_available" => 5,
    #     "mass_kg" => 1240000,
    #     "estimated_cost" => 15000000,
    #     "wormhole_suitability" => %{
    #       "frigate_holes" => true,
    #       "cruiser_holes" => true,
    #       "battleship_holes" => true,
    #       "mass_efficiency" => 0.9
    #     }
    #   }
    # }

    # Pilot assignments and skills (JSONB)
    attribute(:pilot_assignments, :map, default: %{}, public?: true)
    # Format: %{
    #   "95465499" => %{  # Character ID
    #     "character_name" => "Pilot Name",
    #     "assigned_role" => "logistics",
    #     "assigned_ship" => "Guardian",
    #     "skill_readiness" => 0.85,
    #     "availability" => "high",
    #     "experience_rating" => 0.7,
    #     "backup_roles" => ["dps"]
    #   }
    # }

    # Skill gap analysis (JSONB)
    attribute(:skill_gaps, :map, default: %{}, public?: true)
    # Format: %{
    #   "critical_gaps" => [
    #     %{
    #       "pilot_id" => 95465499,
    #       "pilot_name" => "Pilot Name",
    #       "missing_skill" => "Logistics V",
    #       "current_level" => 4,
    #       "required_level" => 5,
    #       "training_time_days" => 12,
    #       "impact" => "high"
    #     }
    #   ],
    #   "role_shortfalls" => %{
    #     "fleet_commander" => %{"shortage" => 0, "qualified_pilots" => 3},
    #     "logistics" => %{"shortage" => 1, "qualified_pilots" => 4},
    #     "tackle" => %{"shortage" => 0, "qualified_pilots" => 8}
    #   },
    #   "training_priorities" => [
    #     %{"skill" => "Logistics V", "pilots_training" => 2, "impact" => "high"},
    #     %{"skill" => "HAC V", "pilots_training" => 3, "impact" => "medium"}
    #   ]
    # }

    # Mass calculations for wormhole operations (JSONB)
    attribute(:mass_calculations, :map, default: %{}, public?: true)
    # Format: %{
    #   "total_fleet_mass_kg" => 45000000,
    #   "wormhole_compatibility" => %{
    #     "frigate_holes" => %{"can_pass" => true, "mass_usage" => 0.15},
    #     "cruiser_holes" => %{"can_pass" => true, "mass_usage" => 0.45},
    #     "battleship_holes" => %{"can_pass" => true, "mass_usage" => 0.75},
    #     "capital_holes" => %{"can_pass" => true, "mass_usage" => 0.25}
    #   },
    #   "mass_optimization" => %{
    #     "efficiency_rating" => 0.82,
    #     "wasted_mass_percentage" => 18.0,
    #     "suggestions" => [
    #       "Replace 1 battleship with 2 cruisers for better mass efficiency"
    #     ]
    #   },
    #   "transport_requirements" => %{
    #     "jumps_required" => 1,
    #     "pods_separate" => false,
    #     "logistics_ships_priority" => true
    #   }
    # }

    # Optimization results and recommendations (JSONB)
    attribute(:optimization_results, :map, default: %{}, public?: true)
    # Format: %{
    #   "fleet_effectiveness" => %{
    #     "dps_rating" => 0.85,
    #     "tank_rating" => 0.78,
    #     "mobility_rating" => 0.92,
    #     "utility_rating" => 0.71,
    #     "overall_rating" => 0.82
    #   },
    #   "counter_doctrines" => [
    #     %{
    #       "threat_type" => "Armor HAC gang",
    #       "effectiveness" => 0.85,
    #       "recommended_changes" => ["Add EWAR support", "Increase alpha damage"]
    #     }
    #   ],
    #   "improvements" => [
    #     %{
    #       "category" => "ship_composition",
    #       "current_score" => 75,
    #       "target_score" => 85,
    #       "recommendation" => "Replace T1 tackle with Interceptors",
    #       "impact" => "medium"
    #     }
    #   ],
    #   "situational_variants" => %{
    #     "home_defense" => %{"modifications" => ["Add HICs", "More logistics"]},
    #     "chain_clearing" => %{"modifications" => ["More DPS", "Less tank"]},
    #     "eviction_response" => %{"modifications" => ["Capital support", "Triage"]}
    #   }
    # }

    # Readiness and availability
    attribute(:current_readiness_percent, :integer, default: 0, public?: true)
    attribute(:pilots_available, :integer, default: 0, public?: true)
    attribute(:pilots_required, :integer, default: 0, public?: true)
    attribute(:estimated_form_up_time_minutes, :integer, default: 30, public?: true)

    timestamps()
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :corporation_id,
        :corporation_name,
        :alliance_id,
        :alliance_name,
        :doctrine_name,
        :doctrine_description,
        :fleet_size_category,
        :minimum_pilots,
        :optimal_pilots,
        :maximum_pilots,
        :created_by
      ])

      validate(fn changeset, _context ->
        case Ash.Changeset.get_attribute(changeset, :fleet_size_category) do
          value when value in ["small", "medium", "large"] or is_nil(value) ->
            :ok

          _ ->
            {:error, field: :fleet_size_category, message: "must be one of: small, medium, large"}
        end
      end)

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:last_updated_at, DateTime.utc_now())
      end)
    end

    update :update_doctrine do
      description("Update doctrine template and requirements")
      require_atomic?(false)

      accept([
        :doctrine_template,
        :ship_requirements,
        :pilot_assignments,
        :skill_gaps,
        :mass_calculations,
        :optimization_results,
        :effectiveness_rating,
        :current_readiness_percent,
        :pilots_available,
        :pilots_required,
        :estimated_form_up_time_minutes
      ])

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.change_attribute(:last_updated_at, DateTime.utc_now())
      end)
    end

    update :record_usage do
      description("Record fleet doctrine usage and outcome")
      require_atomic?(false)

      accept([:success_rate])

      change(fn changeset, _context ->
        current_usage = Ash.Changeset.get_attribute(changeset, :usage_count) || 0

        changeset
        |> Ash.Changeset.change_attribute(:usage_count, current_usage + 1)
        |> Ash.Changeset.change_attribute(:last_updated_at, DateTime.utc_now())
      end)
    end

    # Querying actions
    read :by_corporation do
      description("Find fleet compositions for a corporation")
      argument(:corporation_id, :integer, allow_nil?: false)
      filter(expr(corporation_id == ^arg(:corporation_id)))
    end

    read :by_alliance do
      description("Find fleet compositions for an alliance")
      argument(:alliance_id, :integer, allow_nil?: false)
      filter(expr(alliance_id == ^arg(:alliance_id)))
    end

    read :by_size_category do
      description("Find fleet compositions by size category")
      argument(:size_category, :string, allow_nil?: false)
      filter(expr(fleet_size_category == ^arg(:size_category)))
    end

    read :high_effectiveness do
      description("Find highly effective fleet compositions")
      argument(:threshold, :float, default: 0.8)
      filter(expr(effectiveness_rating >= ^arg(:threshold)))
    end

    read :ready_doctrines do
      description("Find doctrines with high readiness")
      argument(:readiness_threshold, :integer, default: 80)
      filter(expr(current_readiness_percent >= ^arg(:readiness_threshold)))
    end

    read :recent_compositions do
      description("Find recently updated compositions")
      argument(:days, :integer, default: 30)

      filter(expr(last_updated_at >= ago(^arg(:days), :day)))
      prepare(build(sort: [last_updated_at: :desc]))
    end
  end

  code_interface do
    define(:create, action: :create)
    define(:update_doctrine, action: :update_doctrine)
    define(:record_usage, action: :record_usage)
    define(:get_by_corporation, action: :by_corporation, args: [:corporation_id])
    define(:get_by_alliance, action: :by_alliance, args: [:alliance_id])
    define(:get_by_size, action: :by_size_category, args: [:size_category])
    define(:get_high_effectiveness, action: :high_effectiveness, args: [:threshold])
    define(:get_ready_doctrines, action: :ready_doctrines, args: [:readiness_threshold])
    define(:get_recent, action: :recent_compositions, args: [:days])
  end

  calculations do
    calculate :readiness_status, :string do
      description("Fleet readiness status")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.current_readiness_percent do
            percent when percent >= 90 -> "Ready"
            percent when percent >= 70 -> "Mostly Ready"
            percent when percent >= 50 -> "Partial"
            percent when percent >= 30 -> "Limited"
            _ -> "Not Ready"
          end
        end)
      end)
    end

    calculate :effectiveness_rating_text, :string do
      description("Human-readable effectiveness rating")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          case record.effectiveness_rating do
            rating when rating >= 0.9 -> "Excellent"
            rating when rating >= 0.75 -> "Good"
            rating when rating >= 0.6 -> "Fair"
            rating when rating >= 0.4 -> "Poor"
            _ -> "Unproven"
          end
        end)
      end)
    end

    calculate :pilot_fill_percentage, :float do
      description("Percentage of required pilots available")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          if record.pilots_required > 0 do
            Float.round(record.pilots_available / record.pilots_required * 100, 1)
          else
            0.0
          end
        end)
      end)
    end

    calculate :mass_efficiency_rating, :string do
      description("Mass efficiency for wormhole operations")

      calculation(fn records, _context ->
        Enum.map(records, fn record ->
          mass_calc = record.mass_calculations || %{}
          mass_opt = mass_calc["mass_optimization"] || %{}
          efficiency = mass_opt["efficiency_rating"] || 0.0

          case efficiency do
            eff when eff >= 0.9 -> "Highly Efficient"
            eff when eff >= 0.75 -> "Efficient"
            eff when eff >= 0.6 -> "Moderate"
            eff when eff >= 0.4 -> "Inefficient"
            _ -> "Poor"
          end
        end)
      end)
    end

    calculate :days_since_update, :integer do
      description("Days since last update")

      calculation(fn records, _context ->
        now = DateTime.utc_now()

        Enum.map(records, fn record ->
          DateTime.diff(now, record.last_updated_at, :day)
        end)
      end)
    end
  end

  preparations do
    prepare(
      build(
        load: [
          :readiness_status,
          :effectiveness_rating_text,
          :pilot_fill_percentage,
          :mass_efficiency_rating,
          :days_since_update
        ]
      )
    )
  end
end
