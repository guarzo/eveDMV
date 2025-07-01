defmodule EveDmv.Intelligence.WHFleetAnalyzer do
  @moduledoc """
  Wormhole fleet composition analysis and optimization engine.

  Provides intelligent fleet composition recommendations, skill gap analysis,
  mass calculations, and doctrine effectiveness evaluation for wormhole operations.
  """

  require Logger
  alias EveDmv.Eve.EsiClient
  alias EveDmv.Intelligence.{AssetAnalyzer, CharacterStats, WHFleetComposition}

  @doc """
  Analyze and optimize a fleet composition for wormhole operations.

  Options:
  - auth_token: ESI auth token for asset tracking (optional)

  Returns {:ok, composition_record} or {:error, reason}
  """
  def analyze_fleet_composition(composition_id, options \\ []) do
    Logger.info("Starting fleet composition analysis for composition #{composition_id}")

    auth_token = Keyword.get(options, :auth_token)

    with {:ok, composition} <- get_composition_record(composition_id),
         {:ok, available_pilots} <- get_available_pilots(composition.corporation_id),
         {:ok, ship_data} <- get_ship_data(composition.doctrine_template),
         {:ok, asset_data} <- get_asset_availability(composition, auth_token),
         {:ok, skill_analysis} <-
           analyze_skill_requirements(composition.doctrine_template, available_pilots),
         {:ok, mass_analysis} <-
           calculate_mass_efficiency(composition.doctrine_template, ship_data),
         {:ok, pilot_assignments} <-
           optimize_pilot_assignments(
             composition.doctrine_template,
             available_pilots,
             skill_analysis
           ),
         {:ok, optimization_results} <-
           generate_optimization_recommendations(
             composition,
             skill_analysis,
             mass_analysis,
             pilot_assignments
           ) do
      ship_requirements = build_ship_requirements(composition.doctrine_template, ship_data)
      readiness_metrics = calculate_readiness_metrics(pilot_assignments, skill_analysis)

      updated_composition = %{
        ship_requirements: ship_requirements,
        pilot_assignments: pilot_assignments,
        skill_gaps: skill_analysis,
        mass_calculations: mass_analysis,
        optimization_results: optimization_results,
        asset_availability: asset_data,
        current_readiness_percent: readiness_metrics.readiness_percent,
        pilots_available: readiness_metrics.pilots_available,
        pilots_required: readiness_metrics.pilots_required,
        estimated_form_up_time_minutes: readiness_metrics.estimated_form_up_time,
        effectiveness_rating: optimization_results["fleet_effectiveness"]["overall_rating"] || 0.0
      }

      WHFleetComposition.update_doctrine(composition, updated_composition)
    else
      {:error, reason} ->
        Logger.error(
          "Fleet composition analysis failed for composition #{composition_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @doc """
  Create a new fleet composition doctrine for a corporation.
  """
  def create_fleet_doctrine(corporation_id, doctrine_params, options \\ []) do
    Logger.info("Creating new fleet doctrine for corporation #{corporation_id}")

    with {:ok, corp_info} <- get_corporation_info(corporation_id),
         {:ok, doctrine_template} <- build_doctrine_template(doctrine_params),
         {:ok, size_category} <- determine_size_category(doctrine_template) do
      composition_data = %{
        corporation_id: corporation_id,
        corporation_name: corp_info.corporation_name,
        alliance_id: corp_info.alliance_id,
        alliance_name: corp_info.alliance_name,
        doctrine_name: doctrine_params["name"],
        doctrine_description: doctrine_params["description"],
        fleet_size_category: size_category,
        minimum_pilots: calculate_minimum_pilots(doctrine_template),
        optimal_pilots: calculate_optimal_pilots(doctrine_template),
        maximum_pilots: calculate_maximum_pilots(doctrine_template),
        doctrine_template: doctrine_template,
        created_by: Keyword.get(options, :created_by)
      }

      case WHFleetComposition.create(composition_data) do
        {:ok, composition} ->
          # Immediately analyze the new composition
          analyze_fleet_composition(composition.id)

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, reason} ->
        Logger.error("Failed to create fleet doctrine: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Generate counter-doctrine recommendations against a specific threat.
  """
  def generate_counter_doctrine(threat_analysis, corporation_id, options \\ []) do
    Logger.info("Generating counter-doctrine for corporation #{corporation_id}")

    available_pilots = get_available_pilots(corporation_id)
    counter_template = build_counter_template(threat_analysis, available_pilots)

    create_fleet_doctrine(
      corporation_id,
      %{
        "name" => "Counter: #{threat_analysis["threat_name"]}",
        "description" => "Optimized counter-doctrine for #{threat_analysis["threat_type"]}",
        "roles" => counter_template
      },
      options
    )
  end

  # Helper functions for composition analysis
  defp get_composition_record(composition_id) do
    case Ash.get(WHFleetComposition, composition_id, domain: EveDmv.Api) do
      {:ok, composition} -> {:ok, composition}
      {:error, reason} -> {:error, "Composition not found: #{reason}"}
    end
  end

  defp get_corporation_info(corporation_id) do
    case EsiClient.get_corporation(corporation_id) do
      {:ok, corp_data} ->
        # Get alliance info if applicable
        alliance_info =
          if corp_data.alliance_id do
            case EsiClient.get_alliance(corp_data.alliance_id) do
              {:ok, alliance} ->
                %{alliance_id: alliance.alliance_id, alliance_name: alliance.name}

              _ ->
                %{alliance_id: nil, alliance_name: nil}
            end
          else
            %{alliance_id: nil, alliance_name: nil}
          end

        {:ok,
         %{
           corporation_name: corp_data.name,
           alliance_id: alliance_info.alliance_id,
           alliance_name: alliance_info.alliance_name
         }}

      {:error, reason} ->
        Logger.warning(
          "Failed to fetch corporation info from ESI for #{corporation_id}: #{inspect(reason)}"
        )

        # Fallback to placeholder data
        {:ok,
         %{
           corporation_name: "Corporation #{corporation_id}",
           alliance_id: nil,
           alliance_name: nil
         }}
    end
  end

  defp get_available_pilots(corporation_id) do
    # Get corporation members who could participate in fleet operations
    case Ash.read(CharacterStats, domain: EveDmv.Api) do
      {:ok, all_stats} ->
        pilots =
          all_stats
          |> Enum.filter(fn stats -> stats.corporation_id == corporation_id end)
          |> Enum.filter(fn stats -> pilot_available_for_fleet?(stats) end)

        {:ok, pilots}

      {:error, reason} ->
        Logger.warning("Could not load pilot data: #{inspect(reason)}")
        {:ok, []}
    end
  rescue
    error ->
      Logger.error("Error getting available pilots: #{inspect(error)}")
      {:ok, []}
  end

  defp get_ship_data(doctrine_template) when is_map(doctrine_template) do
    # Extract ship types from doctrine and get their data
    ship_types = extract_ship_types_from_doctrine(doctrine_template)

    ship_data =
      Enum.reduce(ship_types, %{}, fn ship_name, acc ->
        Map.put(acc, ship_name, get_ship_info(ship_name))
      end)

    {:ok, ship_data}
  end

  defp get_ship_data(doctrine_template) do
    # Extract ship types from doctrine and get their data
    ship_types = extract_ship_types_from_doctrine(doctrine_template)

    ship_data =
      ship_types
      |> Enum.map(fn ship_name ->
        {ship_name, get_ship_info(ship_name)}
      end)
      |> Enum.into(%{})

    {:ok, ship_data}
  end

  defp get_asset_availability(_composition, nil) do
    # No auth token provided, return placeholder data
    {:ok,
     %{
       "asset_tracking_enabled" => false,
       "ship_availability" => %{},
       "readiness_score" => 0,
       "message" => "Asset tracking requires authentication token"
     }}
  end

  defp get_asset_availability(composition, auth_token) do
    # Use AssetAnalyzer to get real asset data
    case AssetAnalyzer.analyze_fleet_assets(composition.id, auth_token) do
      {:ok, asset_analysis} ->
        {:ok, Map.put(asset_analysis, "asset_tracking_enabled", true)}

      {:error, reason} ->
        Logger.warning("Failed to fetch asset data: #{inspect(reason)}")
        # Return empty asset data on failure
        {:ok,
         %{
           "asset_tracking_enabled" => false,
           "ship_availability" => %{},
           "readiness_score" => 0,
           "error" => "Failed to fetch asset data"
         }}
    end
  end

  defp analyze_skill_requirements(doctrine_template, available_pilots) do
    skill_analysis = %{
      "critical_gaps" => find_critical_skill_gaps(doctrine_template, available_pilots),
      "role_shortfalls" => calculate_role_shortfalls(doctrine_template, available_pilots),
      "training_priorities" => generate_training_priorities(doctrine_template, available_pilots)
    }

    {:ok, skill_analysis}
  end

  defp calculate_mass_efficiency(doctrine_template, ship_data) do
    total_mass = calculate_total_fleet_mass(doctrine_template, ship_data)

    mass_analysis = %{
      "total_fleet_mass_kg" => total_mass,
      "wormhole_compatibility" => calculate_wormhole_compatibility(total_mass),
      "mass_optimization" => generate_mass_optimization_suggestions(doctrine_template, ship_data),
      "transport_requirements" => calculate_transport_requirements(total_mass, doctrine_template)
    }

    {:ok, mass_analysis}
  end

  defp optimize_pilot_assignments(doctrine_template, available_pilots, _skill_analysis) do
    assignments = %{}

    # Assign pilots to roles based on skills and preferences
    assignments =
      doctrine_template
      |> Enum.reduce(assignments, fn {role, role_data}, acc ->
        required_count = role_data["required"] || 1
        assigned_pilots = assign_pilots_to_role(role, role_data, available_pilots, required_count)

        Enum.reduce(assigned_pilots, acc, fn pilot, acc2 ->
          Map.put(acc2, Integer.to_string(pilot.character_id), %{
            "character_name" => pilot.character_name,
            "assigned_role" => role,
            "assigned_ship" => select_best_ship_for_pilot(pilot, role_data["preferred_ships"]),
            "skill_readiness" =>
              calculate_pilot_skill_readiness(pilot, role_data["skills_required"]),
            "availability" => assess_pilot_availability(pilot),
            "experience_rating" => calculate_pilot_experience_rating(pilot, role),
            "backup_roles" => find_backup_roles_for_pilot(pilot, doctrine_template)
          })
        end)
      end)

    {:ok, assignments}
  end

  defp generate_optimization_recommendations(
         composition,
         skill_analysis,
         mass_analysis,
         pilot_assignments
       ) do
    fleet_effectiveness = calculate_fleet_effectiveness(composition, pilot_assignments)
    counter_doctrines = generate_counter_doctrine_analysis(composition)
    improvements = identify_improvement_opportunities(composition, skill_analysis, mass_analysis)
    situational_variants = create_situational_variants(composition)

    optimization = %{
      "fleet_effectiveness" => fleet_effectiveness,
      "counter_doctrines" => counter_doctrines,
      "improvements" => improvements,
      "situational_variants" => situational_variants
    }

    {:ok, optimization}
  end

  # Helper functions for doctrine building
  defp build_doctrine_template(doctrine_params) do
    roles = doctrine_params["roles"] || %{}

    # Convert role definitions to standardized format
    template =
      roles
      |> Enum.map(fn {role_name, role_config} ->
        {role_name,
         %{
           "required" => role_config["required"] || 1,
           "preferred_ships" => role_config["preferred_ships"] || [],
           "skills_required" => role_config["skills_required"] || [],
           "priority" => role_config["priority"] || 5
         }}
      end)
      |> Enum.into(%{})

    {:ok, template}
  end

  defp determine_size_category(doctrine_template) do
    total_pilots =
      doctrine_template
      |> Enum.map(fn {_role, config} -> config["required"] || 1 end)
      |> Enum.sum()

    category =
      cond do
        total_pilots <= 5 -> "small"
        total_pilots <= 15 -> "medium"
        true -> "large"
      end

    {:ok, category}
  end

  defp calculate_minimum_pilots(doctrine_template) do
    # Calculate absolute minimum pilots needed (all required roles filled with 1 pilot each)
    doctrine_template
    |> Enum.map(fn {_role, config} -> min(1, config["required"] || 1) end)
    |> Enum.sum()
  end

  defp calculate_optimal_pilots(doctrine_template) do
    # Calculate optimal pilot count (all required roles fully filled)
    doctrine_template
    |> Enum.map(fn {_role, config} -> config["required"] || 1 end)
    |> Enum.sum()
  end

  defp calculate_maximum_pilots(doctrine_template) do
    # Calculate maximum useful pilots (150% of optimal)
    optimal = calculate_optimal_pilots(doctrine_template)
    round(optimal * 1.5)
  end

  # Ship and mass calculations
  defp extract_ship_types_from_doctrine(doctrine_template) do
    doctrine_template
    |> Enum.flat_map(fn {_role, config} ->
      config["preferred_ships"] || []
    end)
    |> Enum.uniq()
  end

  defp get_ship_info(ship_name) do
    # Map common ship names to EVE type IDs
    ship_name_to_type_id = %{
      "Guardian" => 11_987,
      "Legion" => 29_986,
      "Damnation" => 22_474,
      # Crow as example
      "Interceptor" => 11_379,
      # Broadsword as example
      "Heavy Interdictor" => 12_013,
      # Jaguar as example
      "Assault Frigate" => 11_184,
      "Loki" => 29_990,
      "Proteus" => 29_988,
      "Tengu" => 29_984,
      "Devoter" => 12_017,
      "Phobos" => 12_021,
      "Onyx" => 12_013,
      "Sabre" => 22_456,
      "Flycatcher" => 22_464,
      "Heretic" => 22_452,
      "Eris" => 22_460
    }

    type_id = ship_name_to_type_id[ship_name]

    if type_id do
      case EsiClient.get_type(type_id) do
        {:ok, type_data} ->
          # Get current market price for cost estimation
          cost = estimate_ship_cost(type_id)

          %{
            mass_kg: type_data.mass || 10_000_000,
            estimated_cost: cost,
            type_id: type_id,
            actual_name: type_data.name
          }

        {:error, _reason} ->
          # Fallback to cached/hardcoded data
          fallback_ship_data = %{
            "Guardian" => %{mass_kg: 13_500_000, estimated_cost: 120_000_000},
            "Legion" => %{mass_kg: 15_000_000, estimated_cost: 180_000_000},
            "Damnation" => %{mass_kg: 17_500_000, estimated_cost: 250_000_000},
            "Interceptor" => %{mass_kg: 1_300_000, estimated_cost: 15_000_000},
            "Heavy Interdictor" => %{mass_kg: 12_000_000, estimated_cost: 85_000_000},
            "Assault Frigate" => %{mass_kg: 1_400_000, estimated_cost: 25_000_000}
          }

          fallback_ship_data[ship_name] || %{mass_kg: 10_000_000, estimated_cost: 50_000_000}
      end
    else
      # Unknown ship name, use default values
      %{mass_kg: 10_000_000, estimated_cost: 50_000_000}
    end
  end

  defp estimate_ship_cost(type_id) do
    # Get market prices for Jita (The Forge region)
    case EsiClient.get_market_orders(type_id, 10_000_002, :sell) do
      {:ok, [_ | _] = orders} ->
        # Get the lowest sell price
        orders
        |> Enum.map(& &1.price)
        |> Enum.min()
        |> round()

      _ ->
        # Fallback to a reasonable estimate based on ship class
        50_000_000
    end
  end

  defp calculate_total_fleet_mass(doctrine_template, ship_data) do
    doctrine_template
    |> Enum.map(fn {_role, config} ->
      required = config["required"] || 1
      ships = config["preferred_ships"] || []

      if length(ships) > 0 do
        # Use the first preferred ship for mass calculation
        ship_name = hd(ships)
        ship_info = ship_data[ship_name] || %{mass_kg: 10_000_000}
        required * ship_info.mass_kg
      else
        # Default ship mass
        required * 10_000_000
      end
    end)
    |> Enum.sum()
  end

  defp calculate_wormhole_compatibility(total_mass) do
    # Wormhole mass limits (simplified)
    hole_types = %{
      # 5M kg limit
      "frigate_holes" => 5_000_000,
      # 90M kg limit
      "cruiser_holes" => 90_000_000,
      # 300M kg limit
      "battleship_holes" => 300_000_000,
      # 1.8B kg limit
      "capital_holes" => 1_800_000_000
    }

    hole_types
    |> Enum.map(fn {hole_type, limit} ->
      can_pass = total_mass <= limit
      mass_usage = if can_pass, do: total_mass / limit, else: 999.0

      {hole_type,
       %{
         "can_pass" => can_pass,
         "mass_usage" => Float.round(mass_usage, 2)
       }}
    end)
    |> Enum.into(%{})
  end

  defp generate_mass_optimization_suggestions(doctrine_template, ship_data) do
    total_mass = calculate_total_fleet_mass(doctrine_template, ship_data)
    # Most common WH mass limit
    cruiser_limit = 90_000_000

    efficiency_rating = min(1.0, cruiser_limit / total_mass)
    wasted_mass_percentage = max(0.0, (total_mass - cruiser_limit) / cruiser_limit * 100)

    suggestions = []

    suggestions =
      if total_mass > cruiser_limit do
        suggestions ++ ["Fleet exceeds cruiser hole mass limit"]
      else
        suggestions
      end

    %{
      "efficiency_rating" => Float.round(efficiency_rating, 2),
      "wasted_mass_percentage" => Float.round(wasted_mass_percentage, 1),
      "suggestions" => suggestions
    }
  end

  defp calculate_transport_requirements(total_mass, _doctrine_template) do
    cruiser_limit = 90_000_000

    %{
      "jumps_required" => if(total_mass > cruiser_limit, do: 2, else: 1),
      "pods_separate" => total_mass > cruiser_limit * 0.9,
      "logistics_ships_priority" => true
    }
  end

  # Pilot analysis functions
  defp pilot_available_for_fleet?(pilot_stats) do
    # Determine if a pilot is suitable for fleet operations
    pilot_stats.total_kills + pilot_stats.total_losses >= 5
  end

  defp find_critical_skill_gaps(doctrine_template, available_pilots) do
    # Identify critical skill gaps that prevent doctrine deployment
    gaps = []

    # Check each role for skill requirements
    gaps =
      doctrine_template
      |> Enum.reduce(gaps, fn {role, role_data}, acc ->
        required_skills = role_data["skills_required"] || []
        qualified_pilots = count_qualified_pilots_for_role(available_pilots, required_skills)
        required_count = role_data["required"] || 1

        if qualified_pilots < required_count do
          shortage = required_count - qualified_pilots

          gap_info = %{
            "role" => role,
            "required_pilots" => required_count,
            "qualified_pilots" => qualified_pilots,
            "shortage" => shortage,
            "missing_skills" => required_skills,
            "impact" => if(role_data["priority"] <= 2, do: "critical", else: "high")
          }

          acc ++ [gap_info]
        else
          acc
        end
      end)

    gaps
  end

  defp calculate_role_shortfalls(doctrine_template, available_pilots) do
    doctrine_template
    |> Enum.map(fn {role, role_data} ->
      required_skills = role_data["skills_required"] || []
      qualified_pilots = count_qualified_pilots_for_role(available_pilots, required_skills)
      required_count = role_data["required"] || 1
      shortage = max(0, required_count - qualified_pilots)

      {role,
       %{
         "shortage" => shortage,
         "qualified_pilots" => qualified_pilots
       }}
    end)
    |> Enum.into(%{})
  end

  defp generate_training_priorities(_doctrine_template, _available_pilots) do
    # Generate prioritized list of skills that would have the most impact
    priorities = []

    # This would analyze which skills, if trained, would fill the most gaps
    priorities ++
      [
        %{"skill" => "Logistics V", "pilots_training" => 2, "impact" => "high"},
        %{"skill" => "HAC V", "pilots_training" => 3, "impact" => "medium"}
      ]
  end

  defp assign_pilots_to_role(role, role_data, available_pilots, required_count) do
    # Select the best pilots for this role
    required_skills = role_data["skills_required"] || []

    suitable_pilots =
      available_pilots
      |> Enum.filter(fn pilot -> pilot_meets_skill_requirements?(pilot, required_skills) end)
      |> Enum.sort_by(fn pilot -> calculate_pilot_suitability_score(pilot, role) end, :desc)
      |> Enum.take(required_count)

    suitable_pilots
  end

  defp pilot_meets_skill_requirements?(pilot, required_skills) do
    # Check if pilot meets the skill requirements
    # Note: This would require authenticated ESI access to get actual skills
    # For now, we use heuristics based on pilot's killmail activity

    # If no specific skill requirements, check general competence
    if Enum.empty?(required_skills) do
      pilot.total_kills + pilot.total_losses >= 10
    else
      # Use killmail data as proxy for skills
      # Pilots who fly certain ships likely have the required skills
      case hd(required_skills) do
        "Logistics V" ->
          # Check if they've flown logistics ships
          pilot.ship_groups_flown
          |> Map.get("Logistics", 0)
          |> Kernel.>(0)

        "HAC V" ->
          # Check if they've flown Heavy Assault Cruisers
          pilot.ship_groups_flown
          |> Map.get("Heavy Assault Cruisers", 0)
          |> Kernel.>(0)

        "Interceptors V" ->
          # Check if they've flown interceptors
          pilot.ship_groups_flown
          |> Map.get("Interceptors", 0)
          |> Kernel.>(0)

        "Command Ships V" ->
          # Check if they've flown command ships
          pilot.ship_groups_flown
          |> Map.get("Command Ships", 0)
          |> Kernel.>(0)

        _ ->
          # Generic competence check for unknown skills
          pilot.total_kills + pilot.total_losses >= 20
      end
    end
  end

  defp calculate_pilot_suitability_score(pilot, role) do
    # Calculate how suitable a pilot is for a specific role
    base_score = pilot.total_kills + pilot.total_losses

    # Role-specific bonuses
    role_bonus =
      case role do
        "fleet_commander" -> if pilot.total_kills > 100, do: 50, else: 0
        "logistics" -> if pilot.has_logi_support, do: 30, else: 0
        _ -> 0
      end

    base_score + role_bonus
  end

  defp select_best_ship_for_pilot(_pilot, preferred_ships) do
    # Select the best ship from preferred list for this pilot
    # This would check pilot skills and ship availability
    List.first(preferred_ships) || "Unknown Ship"
  end

  defp calculate_pilot_skill_readiness(_pilot, required_skills) do
    # Calculate how ready the pilot is skill-wise (0.0-1.0)
    # This would check actual skill levels via ESI
    if length(required_skills) > 0 do
      # Placeholder: assume 80% readiness
      0.8
    else
      1.0
    end
  end

  defp assess_pilot_availability(pilot) do
    # Assess pilot availability for fleet operations
    case pilot.avg_gang_size do
      size when size >= 3.0 -> "high"
      size when size >= 1.5 -> "medium"
      _ -> "low"
    end
  end

  defp calculate_pilot_experience_rating(pilot, role) do
    # Calculate pilot experience rating for specific role (0.0-1.0)
    base_experience = min(1.0, (pilot.total_kills + pilot.total_losses) / 100)

    # Role-specific experience bonus
    role_experience =
      case role do
        "fleet_commander" -> if pilot.total_kills > 50, do: 0.2, else: 0.0
        "logistics" -> if pilot.has_logi_support, do: 0.3, else: 0.0
        _ -> 0.0
      end

    Float.round(min(1.0, base_experience + role_experience), 2)
  end

  defp find_backup_roles_for_pilot(pilot, doctrine_template) do
    # Find alternative roles this pilot could fill
    doctrine_template
    |> Enum.filter(fn {_role, role_data} ->
      required_skills = role_data["skills_required"] || []
      pilot_meets_skill_requirements?(pilot, required_skills)
    end)
    |> Enum.map(fn {role, _} -> role end)
    # Limit to 2 backup roles
    |> Enum.take(2)
  end

  defp count_qualified_pilots_for_role(available_pilots, required_skills) do
    available_pilots
    |> Enum.count(fn pilot -> pilot_meets_skill_requirements?(pilot, required_skills) end)
  end

  # Fleet effectiveness calculations
  defp calculate_fleet_effectiveness(composition, pilot_assignments) do
    # Calculate various effectiveness metrics
    pilot_count = map_size(pilot_assignments)

    %{
      "dps_rating" => calculate_dps_rating(composition, pilot_assignments),
      "tank_rating" => calculate_tank_rating(composition, pilot_assignments),
      "mobility_rating" => calculate_mobility_rating(composition, pilot_assignments),
      "utility_rating" => calculate_utility_rating(composition, pilot_assignments),
      "overall_rating" => calculate_overall_effectiveness(pilot_count, composition.optimal_pilots)
    }
  end

  defp calculate_dps_rating(composition, pilot_assignments) do
    # Calculate DPS effectiveness based on ship composition
    dps_pilots =
      pilot_assignments
      |> Enum.count(fn {_id, pilot_data} ->
        pilot_data["assigned_role"] in ["dps", "fleet_commander"]
      end)

    min(1.0, dps_pilots / max(1, composition.optimal_pilots * 0.6))
  end

  defp calculate_tank_rating(composition, pilot_assignments) do
    # Calculate tank/survivability rating
    logi_pilots =
      pilot_assignments
      |> Enum.count(fn {_id, pilot_data} -> pilot_data["assigned_role"] == "logistics" end)

    min(1.0, logi_pilots / max(1, composition.optimal_pilots * 0.25))
  end

  defp calculate_mobility_rating(composition, pilot_assignments) do
    # Calculate mobility/tackle rating
    tackle_pilots =
      pilot_assignments
      |> Enum.count(fn {_id, pilot_data} -> pilot_data["assigned_role"] == "tackle" end)

    min(1.0, tackle_pilots / max(1, composition.optimal_pilots * 0.2))
  end

  defp calculate_utility_rating(composition, pilot_assignments) do
    # Calculate utility/EWAR rating
    utility_pilots =
      pilot_assignments
      |> Enum.count(fn {_id, pilot_data} -> pilot_data["assigned_role"] in ["ewar", "support"] end)

    # Utility is optional, so base rating is higher
    0.7 + min(0.3, utility_pilots / max(1, composition.optimal_pilots * 0.15))
  end

  defp calculate_overall_effectiveness(current_pilots, optimal_pilots) do
    # Overall effectiveness based on pilot fill rate and role balance
    fill_rate = current_pilots / max(1, optimal_pilots)

    cond do
      fill_rate >= 1.0 -> 0.9
      fill_rate >= 0.8 -> 0.75
      fill_rate >= 0.6 -> 0.6
      fill_rate >= 0.4 -> 0.4
      true -> 0.2
    end
  end

  defp generate_counter_doctrine_analysis(_composition) do
    # Generate analysis of how this doctrine performs against common threats
    [
      %{
        "threat_type" => "Armor HAC gang",
        "effectiveness" => 0.85,
        "recommended_changes" => ["Add EWAR support", "Increase alpha damage"]
      },
      %{
        "threat_type" => "Shield cruiser gang",
        "effectiveness" => 0.75,
        "recommended_changes" => ["Add neut pressure", "Focus on mobility"]
      }
    ]
  end

  defp identify_improvement_opportunities(_composition, skill_analysis, mass_analysis) do
    improvements = []

    # Skill-based improvements
    skill_improvements =
      skill_analysis["critical_gaps"]
      |> Enum.map(fn gap ->
        %{
          "category" => "skills",
          "current_score" => 60,
          "target_score" => 85,
          "recommendation" => "Train #{gap["role"]} skills for #{gap["shortage"]} more pilots",
          "impact" => gap["impact"]
        }
      end)

    # Mass efficiency improvements
    mass_improvements =
      if mass_analysis["mass_optimization"]["efficiency_rating"] < 0.8 do
        [
          %{
            "category" => "mass_efficiency",
            "current_score" =>
              round(mass_analysis["mass_optimization"]["efficiency_rating"] * 100),
            "target_score" => 85,
            "recommendation" => "Optimize ship selection for better mass efficiency",
            "impact" => "medium"
          }
        ]
      else
        []
      end

    improvements ++ skill_improvements ++ mass_improvements
  end

  defp create_situational_variants(_composition) do
    # Create variants of the doctrine for different situations
    %{
      "home_defense" => %{
        "modifications" => [
          "Add HICs for tackle",
          "Increase logistics count",
          "Add triage support"
        ]
      },
      "chain_clearing" => %{
        "modifications" => ["More DPS ships", "Reduce logistics", "Add fast tackle"]
      },
      "eviction_response" => %{
        "modifications" => ["Capital support", "Triage carrier", "Multiple fleet coordination"]
      }
    }
  end

  # Readiness and availability calculations
  defp calculate_readiness_metrics(pilot_assignments, skill_analysis) do
    total_assigned = map_size(pilot_assignments)

    # Calculate skill readiness average
    avg_skill_readiness =
      pilot_assignments
      |> Enum.map(fn {_id, pilot} -> pilot["skill_readiness"] || 0.0 end)
      |> Enum.sum()
      |> case do
        0 -> 0.0
        sum -> sum / total_assigned
      end

    # Factor in critical gaps
    critical_gaps = length(skill_analysis["critical_gaps"] || [])
    gap_penalty = min(50, critical_gaps * 15)

    readiness_percent = round(max(0, avg_skill_readiness * 100 - gap_penalty))

    %{
      readiness_percent: readiness_percent,
      pilots_available: total_assigned,
      # This would be calculated from doctrine requirements
      pilots_required: total_assigned,
      estimated_form_up_time: estimate_form_up_time(readiness_percent, total_assigned)
    }
  end

  defp estimate_form_up_time(readiness_percent, pilot_count) do
    # Estimate time to form up the fleet
    # Base 15 minutes
    base_time = 15
    readiness_modifier = (100 - readiness_percent) / 10
    size_modifier = pilot_count / 3

    round(base_time + readiness_modifier + size_modifier)
  end

  defp build_ship_requirements(doctrine_template, ship_data) do
    doctrine_template
    |> Enum.reduce(%{}, fn {role, role_config}, acc ->
      preferred_ships = role_config["preferred_ships"] || []
      required_count = role_config["required"] || 1

      Enum.reduce(preferred_ships, acc, fn ship_name, acc2 ->
        ship_info = ship_data[ship_name] || %{mass_kg: 10_000_000, estimated_cost: 50_000_000}

        # Use a hash of ship_name as type_id for demo purposes
        type_id = :erlang.phash2(ship_name) |> Integer.to_string()

        Map.put(acc2, type_id, %{
          "ship_name" => ship_name,
          "role" => role,
          "quantity_needed" => required_count,
          # Placeholder
          "quantity_available" => 5,
          "mass_kg" => ship_info.mass_kg,
          "estimated_cost" => ship_info.estimated_cost,
          "wormhole_suitability" => %{
            "frigate_holes" => ship_info.mass_kg <= 5_000_000,
            "cruiser_holes" => ship_info.mass_kg <= 90_000_000,
            "battleship_holes" => ship_info.mass_kg <= 300_000_000,
            "mass_efficiency" => calculate_ship_mass_efficiency(ship_info.mass_kg)
          }
        })
      end)
    end)
  end

  defp calculate_ship_mass_efficiency(mass_kg) do
    # Calculate how efficiently a ship uses wormhole mass
    cruiser_limit = 90_000_000
    Float.round(1.0 - mass_kg / cruiser_limit, 2)
  end

  defp build_counter_template(_threat_analysis, _available_pilots) do
    # Build a counter-doctrine template based on threat analysis
    # This would be more sophisticated in production
    %{
      "fleet_commander" => %{
        "required" => 1,
        "preferred_ships" => ["Command Ship"],
        "skills_required" => ["Leadership V"],
        "priority" => 1
      },
      "dps" => %{
        "required" => 4,
        "preferred_ships" => ["HAC", "T3 Cruiser"],
        "skills_required" => ["HAC IV"],
        "priority" => 2
      }
    }
  end
end
