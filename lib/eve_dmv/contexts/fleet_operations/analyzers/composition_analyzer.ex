defmodule EveDmv.Contexts.FleetOperations.Analyzers.CompositionAnalyzer do
  @moduledoc """
  Fleet composition analysis for tactical assessment and optimization.

  Analyzes fleet compositions including ship roles, balance assessment,
  tactical capabilities, and effectiveness ratings. Provides insights
  into fleet strengths, weaknesses, and optimization opportunities.
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Result
  alias EveDmv.Eve.ItemType
  alias EveDmv.Killmails.KillmailRaw

  @doc """
  Analyze fleet composition for effectiveness and tactical balance.
  """
  def analyze(fleet_id, base_data \\ %{}, _opts \\ []) when is_integer(fleet_id) do
    with {:ok, fleet_data} <- get_fleet_data(base_data, fleet_id),
         {:ok, participant_data} <- get_participant_data(base_data, fleet_id) do
      composition_analysis = %{
        fleet_overview: analyze_fleet_overview(fleet_data, participant_data),
        ship_composition: analyze_ship_composition(participant_data),
        role_distribution: analyze_role_distribution(participant_data),
        tactical_capabilities: analyze_tactical_capabilities(participant_data),
        balance_assessment: assess_fleet_balance(participant_data),
        effectiveness_metrics: calculate_effectiveness_metrics(fleet_data, participant_data),
        vulnerability_analysis: analyze_fleet_vulnerabilities(participant_data),
        composition_summary: generate_composition_summary(fleet_data, participant_data)
      }

      Result.ok(composition_analysis)
    else
      {:error, _reason} = error -> error
    end
  rescue
    exception ->
      Result.error(:analysis_failed, "Fleet composition analysis error: #{inspect(exception)}")
  end

  @doc """
  Batch analysis support for multiple fleets.
  """
  def analyze_batch(fleet_ids, base_data, opts \\ []) when is_list(fleet_ids) do
    results =
      fleet_ids
      |> Task.async_stream(
        fn fleet_id ->
          {fleet_id, analyze(fleet_id, base_data, opts)}
        end,
        timeout: 30_000,
        max_concurrency: 4
      )
      |> Enum.map(fn {:ok, result} -> result end)
      |> merge_batch_results()

    Result.ok(results)
  end

  # Analysis implementation

  defp analyze_fleet_overview(fleet_data, participant_data) do
    total_participants = length(participant_data)
    fleet_size_category = categorize_fleet_size(total_participants)
    fleet_commander = identify_fleet_commander(participant_data)
    fleet_duration = calculate_fleet_duration(fleet_data)

    total_fleet_value =
      Enum.sum(Enum.map(participant_data, fn participant -> participant.ship_value || 0 end))

    average_ship_value = safe_divide(total_fleet_value, total_participants)

    %{
      fleet_id: fleet_data.fleet_id,
      fleet_name: fleet_data.fleet_name || "Unknown Fleet",
      total_participants: total_participants,
      fleet_size_category: fleet_size_category,
      fleet_commander: fleet_commander,
      fleet_duration_minutes: fleet_duration,
      total_fleet_value: total_fleet_value,
      average_ship_value: average_ship_value,
      fleet_type: determine_fleet_type(participant_data),
      engagement_status: fleet_data.engagement_status || "Unknown"
    }
  end

  defp analyze_ship_composition(participant_data) do
    # Group by actual ship names for detailed breakdown
    ship_type_composition =
      participant_data
      |> Enum.group_by(fn participant ->
        participant.ship_type || participant.ship_name || "Unknown Ship"
      end)
      |> Enum.map(fn {ship_name, participants} ->
        {ship_name,
         %{
           count: length(participants),
           percentage: safe_divide(length(participants), length(participant_data)) * 100,
           total_value: Enum.sum(Enum.map(participants, &(&1.ship_value || 0))),
           ship_class: get_ship_class_from_participant(List.first(participants)),
           pilots: Enum.map(participants, &(&1.character_name || "Unknown"))
         }}
      end)
      |> Enum.into(%{})

    # Also group by ship class for high-level overview
    ship_class_composition =
      participant_data
      |> Enum.group_by(fn participant ->
        participant.ship_group || get_ship_class_from_participant(participant) || "Unknown Class"
      end)
      |> Enum.map(fn {ship_class, participants} ->
        {ship_class,
         %{
           count: length(participants),
           percentage: safe_divide(length(participants), length(participant_data)) * 100,
           ship_types:
             participants
             |> Enum.map(&(&1.ship_type || &1.ship_name || "Unknown"))
             |> Enum.frequencies()
         }}
      end)
      |> Enum.into(%{})

    most_common_ships =
      ship_type_composition
      |> Enum.sort_by(fn {_ship, data} -> data.count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {ship_name, data} ->
        %{ship_name: ship_name, count: data.count, percentage: data.percentage}
      end)

    diversity_index = calculate_ship_diversity(ship_type_composition)

    %{
      ship_breakdown: ship_type_composition,
      ship_class_breakdown: ship_class_composition,
      most_common_ships: most_common_ships,
      unique_ship_types: map_size(ship_type_composition),
      unique_ship_classes: map_size(ship_class_composition),
      diversity_index: diversity_index,
      composition_balance: assess_composition_balance(ship_class_composition)
    }
  end

  # Helper function to get ship class from participant data
  defp get_ship_class_from_participant(participant) do
    participant.ship_group ||
      participant.ship_category ||
      (participant.ship_type_id && get_basic_ship_class(participant.ship_type_id)) ||
      "Unknown Class"
  end

  # Use static data system for ship classification - no hardcoding!
  defp get_basic_ship_class(ship_type_id) when is_integer(ship_type_id) do
    case get_ship_info_from_static_data(ship_type_id) do
      {:ok, ship_info} ->
        Map.get(ship_info, :group_name, "Unknown Class")

      {:error, _} ->
        "Unknown Class"
    end
  end

  # Query the actual static data system for ship information
  defp get_ship_info_from_static_data(ship_type_id) do
    try do
      case Ash.get(ItemType, ship_type_id, domain: EveDmv.Api) do
        {:ok, item_type} ->
          {:ok,
           %{
             group_name: item_type.group_name,
             category_name: item_type.category_name,
             type_name: item_type.type_name,
             is_ship: item_type.is_ship,
             is_capital_ship: item_type.is_capital_ship,
             mass: item_type.mass,
             volume: item_type.volume
           }}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      _ -> {:error, :static_data_unavailable}
    end
  end

  # Convert ship group to tactical role, enhanced with killmail fitting analysis
  defp get_tactical_role_from_group(group_name, ship_type_id) when is_integer(ship_type_id) do
    # First try to get role from killmail fitting analysis
    case get_role_from_killmail_analysis(ship_type_id) do
      {:ok, role, confidence} when confidence > 0.6 -> role
      _ -> get_static_tactical_role(group_name)
    end
  end

  defp get_tactical_role_from_group(group_name, _ship_type_id) do
    # Fallback when ship_type_id is nil or invalid
    get_static_tactical_role(group_name)
  end

  # Analyze ship role based on recent killmail fitting data
  defp get_role_from_killmail_analysis(ship_type_id) do
    try do
      # Get recent killmails for this ship type (last 7 days)
      _end_time = DateTime.utc_now()
      _start_time = DateTime.add(_end_time, -7, :day)

      # For now, disable killmail analysis to avoid query complexity
      # This can be implemented later with proper Ash query syntax
      {:error, :not_implemented}

      # TODO: Implement proper Ash query for killmail analysis
      # query = KillmailRaw
      # |> Ash.Query.filter(victim_ship_type_id == ^ship_type_id)
      # |> Ash.Query.filter(killmail_time >= ^start_time)
      # |> Ash.Query.limit(50)
    rescue
      _ -> {:error, :analysis_failed}
    end
  end

  # Analyze fitting patterns from killmail data
  defp analyze_fitting_patterns(killmails) do
    killmails
    |> Enum.map(&extract_fitted_modules/1)
    |> Enum.map(&classify_ship_role_from_modules/1)
    |> Enum.frequencies()
  end

  # Extract fitted modules from killmail raw data
  defp extract_fitted_modules(killmail) do
    case killmail.raw_data do
      %{"victim" => %{"items" => items}} when is_list(items) ->
        items
        |> Enum.filter(&is_fitted_module/1)
        |> Enum.map(&get_module_name/1)

      _ ->
        []
    end
  end

  # Check if an item is a fitted module (not cargo)
  defp is_fitted_module(item) do
    flag = item["flag"] || 0
    # High slots: 27-34, Mid slots: 19-26, Low slots: 11-18, Rigs: 92-94
    flag in 11..34 or flag in 92..94
  end

  # Get module name for classification
  defp get_module_name(item) do
    item["type_name"] || item["item_name"] || "Unknown Module"
  end

  # Classify ship role based on fitted modules
  defp classify_ship_role_from_modules(modules) do
    role_scores = %{
      tackle: calculate_tackle_score(modules),
      logistics: calculate_logistics_score(modules),
      ewar: calculate_ewar_score(modules),
      dps: calculate_dps_score(modules),
      command: calculate_command_score(modules),
      exploration: calculate_exploration_score(modules)
    }

    # Return the role with highest score if above threshold
    {role, score} = Enum.max_by(role_scores, fn {_role, score} -> score end)

    if score > 0.3 do
      role
    else
      # No clear role determined
      :mixed
    end
  end

  # Calculate tackle score based on fitted modules
  defp calculate_tackle_score(modules) do
    tackle_indicators = [
      "Warp Scrambler",
      "Warp Disruptor",
      "Stasis Webifier",
      "Interdiction Sphere Launcher",
      "Heavy Interdiction",
      # Tackle rig
      "Small Processor Overclocking Unit"
    ]

    count_module_matches(modules, tackle_indicators) / max(1, length(modules))
  end

  # Calculate logistics score based on fitted modules  
  defp calculate_logistics_score(modules) do
    logistics_indicators = [
      "Remote Shield Booster",
      "Remote Armor Repairer",
      "Remote Capacitor Transmitter",
      "Remote Shield Transporter",
      "Logistics",
      "Triage Module"
    ]

    count_module_matches(modules, logistics_indicators) / max(1, length(modules))
  end

  # Calculate EWAR score based on fitted modules
  defp calculate_ewar_score(modules) do
    ewar_indicators = [
      "ECM",
      "Remote Sensor Dampener",
      "Tracking Disruptor",
      "Target Painter",
      "Energy Neutralizer",
      "Energy Vampire",
      "Signal Distortion Amplifier"
    ]

    count_module_matches(modules, ewar_indicators) / max(1, length(modules))
  end

  # Calculate DPS score based on fitted modules
  defp calculate_dps_score(modules) do
    dps_indicators = [
      "Autocannon",
      "Artillery",
      "Railgun",
      "Blaster",
      "Pulse Laser",
      "Beam Laser",
      "Launcher",
      "Torpedo",
      "Cruise",
      "Heavy Missile",
      "Drone Damage Amplifier"
    ]

    count_module_matches(modules, dps_indicators) / max(1, length(modules))
  end

  # Calculate command score based on fitted modules
  defp calculate_command_score(modules) do
    command_indicators = [
      "Command Burst",
      "Warfare Link",
      "Command Processor",
      "Armored Command",
      "Information Command",
      "Skirmish Command"
    ]

    count_module_matches(modules, command_indicators) / max(1, length(modules))
  end

  # Calculate exploration score based on fitted modules
  defp calculate_exploration_score(modules) do
    exploration_indicators = [
      "Probe Launcher",
      "Scan",
      "Hacking",
      "Archaeology",
      "Data Analyzer",
      "Relic Analyzer",
      "Covert Ops Cloaking"
    ]

    count_module_matches(modules, exploration_indicators) / max(1, length(modules))
  end

  # Count how many modules match the given indicators
  defp count_module_matches(modules, indicators) do
    modules
    |> Enum.count(fn module ->
      Enum.any?(indicators, &String.contains?(module, &1))
    end)
    |> Float.round(2)
  end

  # Determine primary role from fitting analysis with confidence score
  defp determine_primary_role_from_fittings(role_frequencies) do
    total_samples = Enum.sum(Map.values(role_frequencies))

    case Enum.max_by(role_frequencies, fn {_role, count} -> count end, fn -> {:mixed, 0} end) do
      {role, count} when count > 0 ->
        confidence = count / total_samples
        {:ok, role, confidence}

      _ ->
        {:error, :no_clear_role}
    end
  end

  # Static classification fallback
  defp get_static_tactical_role(group_name) do
    case group_name do
      # DPS Ships
      "Frigate" ->
        :dps

      "Destroyer" ->
        :dps

      "Cruiser" ->
        :dps

      "Combat Battlecruiser" ->
        :dps

      "Attack Battlecruiser" ->
        :dps

      "Battleship" ->
        :heavy_dps

      "Assault Frigate" ->
        :dps

      "Heavy Assault Cruiser" ->
        :dps

      "Marauder" ->
        :heavy_dps

      # Tackle Ships
      "Interceptor" ->
        :tackle

      "Interdictor" ->
        :tackle

      "Heavy Interdiction Cruiser" ->
        :tackle

      # EWAR Ships
      "Electronic Attack Ship" ->
        :ewar

      "Combat Recon Ship" ->
        :ewar

      "Force Recon Ship" ->
        :ewar

      # Support Ships
      "Logistics" ->
        :logistics

      "Logistics Frigate" ->
        :logistics

      "Force Auxiliary" ->
        :logistics

      "Command Ship" ->
        :command

      "Command Destroyer" ->
        :command

      # Stealth Ships
      "Covert Ops" ->
        :stealth

      "Stealth Bomber" ->
        :stealth

      "Black Ops" ->
        :stealth

      # Flexible Ships
      "Strategic Cruiser" ->
        :flexible

      "Tactical Destroyer" ->
        :flexible

      # Capital Ships
      "Dreadnought" ->
        :capital_dps

      "Carrier" ->
        :capital_support

      "Supercarrier" ->
        :capital_dps

      "Titan" ->
        :capital_dps

      # Industrial (shouldn't be in combat fleets but handle gracefully)
      group
      when group in [
             "Hauler",
             "Deep Space Transport",
             "Blockade Runner",
             "Mining Barge",
             "Exhumer",
             "Freighter",
             "Jump Freighter"
           ] ->
        :industrial

      _ ->
        :other
    end
  end

  defp get_basic_ship_class(_), do: "Unknown Class"

  defp analyze_role_distribution(participant_data) do
    role_distribution =
      participant_data
      |> Enum.group_by(fn participant ->
        # Use static data to get proper ship group and then tactical role
        ship_type_id = participant.ship_type_id

        case get_ship_info_from_static_data(ship_type_id) do
          {:ok, ship_info} ->
            # Enhanced role detection with killmail analysis
            get_tactical_role_from_group(ship_info.group_name, ship_type_id)

          {:error, _} ->
            # Fallback to existing ship_group field if static data fails
            categorize_ship_role(participant.ship_group || "Unknown")
        end
      end)
      |> Enum.map(fn {role, participants} ->
        count = length(participants)
        percentage = safe_divide(count, length(participant_data)) * 100

        {role,
         %{
           count: count,
           percentage: percentage,
           participants:
             Enum.map(participants, fn p ->
               %{
                 character_name: p.character_name,
                 ship_type: p.ship_type,
                 experience_level: assess_pilot_experience(p)
               }
             end)
         }}
      end)
      |> Enum.into(%{})

    role_balance = assess_role_balance(role_distribution)
    missing_roles = identify_missing_roles(role_distribution)

    %{
      role_breakdown: role_distribution,
      role_balance_score: role_balance,
      missing_critical_roles: missing_roles,
      dps_ratio: get_role_percentage(role_distribution, :dps),
      support_ratio: get_role_percentage(role_distribution, :support),
      tank_ratio: get_role_percentage(role_distribution, :tank),
      ewar_ratio: get_role_percentage(role_distribution, :ewar)
    }
  end

  defp analyze_tactical_capabilities(participant_data) do
    damage_analysis = analyze_damage_capabilities(participant_data)
    ewar_analysis = analyze_ewar_capabilities(participant_data)
    logistics_analysis = analyze_logistics_capabilities(participant_data)
    mobility_analysis = analyze_mobility_capabilities(participant_data)
    range_analysis = analyze_range_capabilities(participant_data)

    %{
      damage_projection: damage_analysis,
      electronic_warfare: ewar_analysis,
      logistics_support: logistics_analysis,
      mobility_profile: mobility_analysis,
      engagement_range: range_analysis,
      overall_tactical_rating: calculate_tactical_rating(participant_data)
    }
  end

  defp assess_fleet_balance(participant_data) do
    role_distribution =
      Enum.group_by(participant_data, fn participant ->
        categorize_ship_role(participant.ship_group || "Unknown")
      end)

    role_balance = assess_role_balance_detailed(role_distribution)
    size_balance = assess_ship_size_balance(participant_data)
    value_balance = assess_value_distribution(participant_data)
    experience_balance = assess_experience_distribution(participant_data)

    overall_balance =
      calculate_overall_balance_score([
        role_balance,
        size_balance,
        value_balance,
        experience_balance
      ])

    %{
      role_balance: role_balance,
      ship_size_balance: size_balance,
      value_distribution: value_balance,
      experience_distribution: experience_balance,
      overall_balance_score: overall_balance,
      balance_recommendations: generate_balance_recommendations(role_distribution)
    }
  end

  defp calculate_effectiveness_metrics(_fleet_data, participant_data) do
    estimated_dps = calculate_estimated_dps(participant_data)
    alpha_strike = calculate_alpha_strike_potential(participant_data)
    effective_hp = calculate_effective_hp(participant_data)
    logistics_power = calculate_logistics_power(participant_data)
    engagement_flexibility = assess_engagement_flexibility(participant_data)
    doctrine_compliance = assess_doctrine_compliance(participant_data)

    %{
      firepower: %{
        estimated_dps: estimated_dps,
        alpha_strike_potential: alpha_strike,
        damage_application: assess_damage_application(participant_data)
      },
      survivability: %{
        effective_hp: effective_hp,
        logistics_power: logistics_power,
        tank_efficiency: calculate_tank_efficiency(participant_data)
      },
      tactical: %{
        engagement_flexibility: engagement_flexibility,
        doctrine_compliance: doctrine_compliance,
        coordination_potential: assess_coordination_potential(participant_data)
      },
      overall_effectiveness:
        calculate_overall_effectiveness(estimated_dps, effective_hp, logistics_power)
    }
  end

  defp analyze_fleet_vulnerabilities(participant_data) do
    critical_gaps = identify_critical_role_gaps(participant_data)
    ship_vulnerabilities = identify_ship_vulnerabilities(participant_data)
    tactical_weaknesses = identify_tactical_weaknesses(participant_data)
    counter_susceptibility = assess_counter_fleet_susceptibility(participant_data)

    %{
      critical_role_gaps: critical_gaps,
      ship_vulnerabilities: ship_vulnerabilities,
      tactical_weaknesses: tactical_weaknesses,
      counter_fleet_susceptibility: counter_susceptibility,
      overall_vulnerability_score: calculate_vulnerability_score(participant_data),
      mitigation_recommendations: generate_vulnerability_mitigations(participant_data)
    }
  end

  defp generate_composition_summary(fleet_data, participant_data) do
    total_participants = length(participant_data)
    composition_type = determine_composition_type(participant_data)
    effectiveness_rating = assess_overall_effectiveness(participant_data)

    key_stats = %{
      total_pilots: total_participants,
      estimated_combat_power: calculate_combat_power_index(participant_data),
      fleet_value: Enum.sum(Enum.map(participant_data, &(&1.ship_value || 0))),
      average_pilot_experience: calculate_average_experience(participant_data)
    }

    strategic_role = determine_strategic_role(participant_data)
    optimal_engagement = determine_optimal_engagement_type(participant_data)

    %{
      fleet_name: fleet_data.fleet_name || "Unknown Fleet",
      composition_type: composition_type,
      strategic_role: strategic_role,
      effectiveness_rating: effectiveness_rating,
      optimal_engagement_type: optimal_engagement,
      key_statistics: key_stats,
      primary_strengths: identify_primary_strengths(participant_data),
      primary_weaknesses: identify_primary_weaknesses(participant_data),
      tactical_recommendations: generate_tactical_recommendations(participant_data),
      analysis_confidence: calculate_analysis_confidence(participant_data),
      fleet_insights: generate_fleet_insights(participant_data, %{})
    }
  end

  # Helper functions

  defp get_fleet_data(base_data, fleet_id) do
    case get_in(base_data, [:fleet_data, fleet_id]) do
      nil -> {:error, :fleet_not_found}
      fleet_data -> {:ok, fleet_data}
    end
  end

  defp get_participant_data(base_data, fleet_id) do
    case get_in(base_data, [:fleet_participants, fleet_id]) do
      nil -> {:ok, []}
      participants -> {:ok, participants}
    end
  end

  defp categorize_fleet_size(participant_count) do
    cond do
      participant_count >= 200 -> :fleet
      participant_count >= 50 -> :large_gang
      participant_count >= 20 -> :medium_gang
      participant_count >= 10 -> :small_gang
      participant_count >= 5 -> :squad
      true -> :solo_small
    end
  end

  defp identify_fleet_commander(participant_data) do
    commander =
      Enum.find(participant_data, fn participant ->
        participant.fleet_role == "Fleet Commander" ||
          participant.is_fleet_commander == true
      end)

    case commander do
      nil ->
        %{name: "Unknown", role: "Unknown"}

      fc ->
        %{
          name: fc.character_name,
          role: fc.fleet_role || "Fleet Commander",
          experience: assess_pilot_experience(fc)
        }
    end
  end

  defp calculate_fleet_duration(fleet_data) do
    case {fleet_data.start_time, fleet_data.end_time} do
      {start_time, end_time} when start_time != nil and end_time != nil ->
        with {:ok, start_dt, _} <- DateTime.from_iso8601(start_time),
             {:ok, end_dt, _} <- DateTime.from_iso8601(end_time) do
          DateTime.diff(end_dt, start_dt, :minute)
        else
          _ -> 0
        end

      _ ->
        0
    end
  end

  defp determine_fleet_type(participant_data) do
    ship_groups =
      Enum.frequencies(Enum.map(participant_data, & &1.ship_group))

    cond do
      Map.has_key?(ship_groups, "Dreadnought") or Map.has_key?(ship_groups, "Carrier") ->
        :capital_fleet

      Map.has_key?(ship_groups, "Battleship") and length(participant_data) > 20 ->
        :battleship_fleet

      Map.has_key?(ship_groups, "Cruiser") and length(participant_data) > 10 ->
        :cruiser_fleet

      Map.has_key?(ship_groups, "Frigate") and length(participant_data) > 5 ->
        :frigate_gang

      true ->
        :mixed_composition
    end
  end

  defp calculate_ship_diversity(ship_composition) do
    if map_size(ship_composition) <= 1, do: 0.0

    total_ships =
      ship_composition
      |> Map.values()
      |> Enum.map(& &1.count)
      |> Enum.sum()

    ship_composition
    |> Map.values()
    |> Enum.map(fn group_data ->
      proportion = group_data.count / total_ships
      if proportion > 0, do: -proportion * :math.log2(proportion), else: 0
    end)
    |> Enum.sum()
  end

  defp categorize_ship_role(ship_group) do
    cond do
      String.contains?(ship_group, ["Battleship", "Dreadnought"]) -> :heavy_dps
      String.contains?(ship_group, ["Cruiser", "Destroyer", "Frigate"]) -> :dps
      String.contains?(ship_group, ["Logistics"]) -> :support
      String.contains?(ship_group, ["Interceptor", "Assault Frigate"]) -> :tackle
      String.contains?(ship_group, ["Electronic", "ECM", "Recon"]) -> :ewar
      String.contains?(ship_group, ["Command"]) -> :command
      true -> :other
    end
  end

  defp assess_pilot_experience(_participant), do: :moderate

  defp get_role_percentage(role_distribution, role) do
    case Map.get(role_distribution, role) do
      nil -> 0.0
      role_data -> role_data.percentage
    end
  end

  defp safe_divide(numerator, denominator) when denominator > 0, do: numerator / denominator
  defp safe_divide(_, _), do: 0.0

  defp merge_batch_results(results) do
    Enum.reduce(results, %{}, fn {fleet_id, result}, acc ->
      Map.put(acc, fleet_id, result)
    end)
  end

  # Placeholder implementations for complex analysis functions
  defp assess_composition_balance(_ship_composition), do: :balanced

  defp assess_role_balance(role_distribution) do
    # Calculate balance based on role diversity and ratios
    # Handle both simple counts and map structures
    total_ships =
      role_distribution
      |> Map.values()
      |> Enum.map(fn
        %{count: count} when is_number(count) -> count
        count when is_number(count) -> count
        _ -> 0
      end)
      |> Enum.sum()

    if total_ships == 0 do
      0.0
    else
      # Ideal ratios for different roles
      ideal_ratios = %{
        # 60% DPS ships
        dps: 0.6,
        # 15% logistics
        logistics: 0.15,
        # 10% EWAR
        ewar: 0.1,
        # 10% tackle
        tackle: 0.1,
        # 5% other support
        support: 0.05
      }

      # Calculate how close actual ratios are to ideal
      balance_scores =
        ideal_ratios
        |> Enum.map(fn {role, ideal_ratio} ->
          role_data = Map.get(role_distribution, role, 0)

          actual_count =
            case role_data do
              %{count: count} when is_number(count) -> count
              count when is_number(count) -> count
              _ -> 0
            end

          actual_ratio = if total_ships > 0, do: actual_count / total_ships, else: 0.0

          # Score based on how close to ideal (100 = perfect, 0 = very far)
          ratio_diff = abs(actual_ratio - ideal_ratio)
          # Penalty for deviation
          max(0, 100 - ratio_diff * 200)
        end)

      # Average the balance scores
      if length(balance_scores) > 0 do
        Enum.sum(balance_scores) / length(balance_scores)
      else
        0.0
      end
    end
  end

  defp identify_missing_roles(role_distribution) do
    total_ships =
      role_distribution
      |> Map.values()
      |> Enum.map(fn
        %{count: count} when is_number(count) -> count
        count when is_number(count) -> count
        _ -> 0
      end)
      |> Enum.sum()

    if total_ships == 0 do
      [:dps, :logistics, :ewar, :tackle]
    else
      # Minimum thresholds for each role
      min_thresholds = %{
        # At least 5% logistics
        logistics: 0.05,
        # At least 3% EWAR
        ewar: 0.03,
        # At least 5% tackle
        tackle: 0.05,
        # At least 40% DPS
        dps: 0.4
      }

      min_thresholds
      |> Enum.filter(fn {role, min_ratio} ->
        role_data = Map.get(role_distribution, role, 0)

        actual_count =
          case role_data do
            %{count: count} when is_number(count) -> count
            count when is_number(count) -> count
            _ -> 0
          end

        actual_ratio = if total_ships > 0, do: actual_count / total_ships, else: 0.0
        actual_ratio < min_ratio
      end)
      |> Enum.map(&elem(&1, 0))
    end
  end

  defp analyze_damage_capabilities(participant_data) do
    # Calculate estimated DPS based on actual ship types
    total_dps =
      participant_data
      |> Enum.map(&estimate_ship_dps/1)
      |> Enum.sum()

    # Rate damage capabilities based on fleet size and total DPS
    fleet_size = length(participant_data)
    dps_per_pilot = if fleet_size > 0, do: total_dps / fleet_size, else: 0

    rating =
      cond do
        dps_per_pilot > 800 -> :excellent
        dps_per_pilot > 500 -> :good
        dps_per_pilot > 300 -> :moderate
        dps_per_pilot > 100 -> :weak
        true -> :poor
      end

    %{rating: rating, estimated_dps: round(total_dps)}
  end

  defp analyze_ewar_capabilities(_participant_data), do: %{rating: :moderate, jam_strength: 5}

  defp analyze_logistics_capabilities(participant_data) do
    # Identify logistics ships
    # Basic logi ship types
    logi_ships = [11985, 11987, 11989, 625, 624, 11978, 22474]

    logi_count =
      participant_data
      |> Enum.count(fn participant ->
        ship_type_id = participant[:ship_type_id] || participant["ship_type_id"]
        ship_type_id in logi_ships
      end)

    fleet_size = length(participant_data)
    logi_ratio = if fleet_size > 0, do: logi_count / fleet_size, else: 0

    # Estimate rep power based on logi ships present
    # Rough estimate per logi ship
    rep_power = logi_count * 800

    rating =
      cond do
        logi_ratio > 0.2 -> :excellent
        logi_ratio > 0.15 -> :good
        logi_ratio > 0.1 -> :moderate
        logi_ratio > 0.05 -> :weak
        true -> :poor
      end

    %{rating: rating, rep_power: rep_power, logi_count: logi_count}
  end

  defp analyze_mobility_capabilities(participant_data) do
    # Estimate average speed based on ship classes
    total_speed =
      participant_data
      |> Enum.map(&estimate_ship_speed/1)
      |> Enum.sum()

    fleet_size = length(participant_data)
    avg_speed = if fleet_size > 0, do: total_speed / fleet_size, else: 0

    rating =
      cond do
        avg_speed > 2000 -> :excellent
        avg_speed > 1500 -> :good
        avg_speed > 1000 -> :moderate
        avg_speed > 500 -> :weak
        true -> :poor
      end

    %{rating: rating, avg_speed: round(avg_speed)}
  end

  defp estimate_ship_speed(participant) do
    ship_type_id = participant[:ship_type_id] || participant["ship_type_id"]

    case ship_type_id do
      nil ->
        0

      id when is_integer(id) ->
        cond do
          # Frigates (fast)
          id in 582..650 -> 2500
          # Destroyers (fast)
          id in 324..380 -> 2200
          # Cruisers (medium)
          id in 620..634 -> 1800
          # Battlecruisers (slow)
          id in 1201..1310 -> 1200
          # Battleships (slow)
          id in 638..645 -> 800
          # Carriers (very slow)
          id in 547..554 -> 400
          # Dreadnoughts (very slow)
          id in 670..673 -> 300
          # Titans (extremely slow)
          id in 3514..3518 -> 200
          # T3 Cruisers (medium-fast)
          id in 11567..12034 -> 1900
          # T3 Destroyers (fast)
          id in 29984..29990 -> 2300
          # Default
          true -> 1500
        end

      _ ->
        0
    end
  end

  defp analyze_range_capabilities(_participant_data), do: %{optimal: :medium, falloff: :good}
  defp calculate_tactical_rating(_participant_data), do: 70.0
  defp assess_role_balance_detailed(_role_distribution), do: 75.0
  defp assess_ship_size_balance(_participant_data), do: 80.0
  defp assess_value_distribution(_participant_data), do: 60.0
  defp assess_experience_distribution(_participant_data), do: 70.0
  defp calculate_overall_balance_score(scores), do: Enum.sum(scores) / length(scores)

  defp generate_balance_recommendations(_role_distribution),
    do: ["Add logistics support", "Improve EWAR coverage"]

  defp calculate_estimated_dps(participant_data) do
    participant_data
    |> Enum.map(&estimate_ship_dps/1)
    |> Enum.sum()
    |> round()
  end

  # Helper function to estimate DPS based on ship type
  defp estimate_ship_dps(participant) do
    ship_type_id = participant[:ship_type_id] || participant["ship_type_id"]

    case ship_type_id do
      nil ->
        0

      id when is_integer(id) ->
        cond do
          # Frigates
          id in 582..650 -> 150
          # Destroyers  
          id in 324..380 -> 200
          # Cruisers
          id in 620..634 -> 350
          # Battlecruisers
          id in 1201..1310 -> 600
          # Battleships
          id in 638..645 -> 800
          # Carriers
          id in 547..554 -> 2000
          # Dreadnoughts
          id in 670..673 -> 5000
          # Titans
          id in 3514..3518 -> 8000
          # T3 Cruisers
          id in 11567..12034 -> 450
          # T3 Destroyers
          id in 29984..29990 -> 250
          # Default
          true -> 200
        end

      _ ->
        0
    end
  end

  defp calculate_alpha_strike_potential(_participant_data), do: 50_000

  defp calculate_effective_hp(participant_data) do
    participant_data
    |> Enum.map(&estimate_ship_ehp/1)
    |> Enum.sum()
    |> round()
  end

  # Helper function to estimate EHP based on ship type
  defp estimate_ship_ehp(participant) do
    ship_type_id = participant[:ship_type_id] || participant["ship_type_id"]

    case ship_type_id do
      nil ->
        0

      id when is_integer(id) ->
        cond do
          # Frigates
          id in 582..650 -> 8_000
          # Destroyers
          id in 324..380 -> 15_000
          # Cruisers
          id in 620..634 -> 35_000
          # Battlecruisers
          id in 1201..1310 -> 80_000
          # Battleships
          id in 638..645 -> 150_000
          # Carriers
          id in 547..554 -> 8_000_000
          # Dreadnoughts
          id in 670..673 -> 15_000_000
          # Titans
          id in 3514..3518 -> 50_000_000
          # T3 Cruisers
          id in 11567..12034 -> 45_000
          # T3 Destroyers
          id in 29984..29990 -> 20_000
          # Default
          true -> 25_000
        end

      _ ->
        0
    end
  end

  defp calculate_logistics_power(_participant_data), do: 3000
  defp assess_engagement_flexibility(_participant_data), do: :moderate
  defp assess_doctrine_compliance(_participant_data), do: 85.0
  defp assess_damage_application(_participant_data), do: :good
  defp calculate_tank_efficiency(_participant_data), do: 0.75
  defp assess_coordination_potential(_participant_data), do: :high

  defp calculate_overall_effectiveness(dps, ehp, logi),
    do: (dps * 0.4 + ehp * 0.3 + logi * 0.3) / 1000

  defp identify_critical_role_gaps(_participant_data), do: [:logistics, :command]
  defp identify_ship_vulnerabilities(_participant_data), do: ["Weak to bombers", "Limited range"]
  defp identify_tactical_weaknesses(_participant_data), do: ["Poor mobility", "Limited EWAR"]

  defp assess_counter_fleet_susceptibility(_participant_data),
    do: %{bombers: :high, capitals: :low}

  defp calculate_vulnerability_score(_participant_data), do: 45.0

  defp generate_vulnerability_mitigations(_participant_data),
    do: ["Add interceptors", "Improve logistics"]

  defp determine_composition_type(_participant_data), do: :doctrine_fleet
  defp assess_overall_effectiveness(_participant_data), do: :good
  defp calculate_combat_power_index(_participant_data), do: 850
  defp calculate_average_experience(_participant_data), do: :experienced
  defp determine_strategic_role(_participant_data), do: :line_combat
  defp determine_optimal_engagement_type(_participant_data), do: :medium_range_brawl
  defp identify_primary_strengths(_participant_data), do: ["High DPS", "Good organization"]
  defp identify_primary_weaknesses(_participant_data), do: ["Limited logistics", "Poor EWAR"]

  defp generate_tactical_recommendations(_participant_data),
    do: ["Maintain range", "Focus fire", "Use logistics effectively"]

  defp calculate_analysis_confidence(participant_data),
    do: if(length(participant_data) > 10, do: :high, else: :moderate)

  # Generate meaningful fleet insights based on actual ship composition
  defp generate_fleet_insights(participant_data, role_distribution) do
    total_pilots = length(participant_data)

    # Analyze the actual ship groups present
    ship_groups =
      participant_data
      |> Enum.map(fn participant ->
        case get_ship_info_from_static_data(participant.ship_type_id) do
          {:ok, ship_info} -> ship_info.group_name
          {:error, _} -> "Unknown"
        end
      end)
      |> Enum.frequencies()

    # Generate specific insights based on composition
    insights = []

    # Strategic Cruiser heavy fleet analysis
    insights =
      if Map.get(ship_groups, "Strategic Cruiser", 0) > total_pilots * 0.5 do
        [
          "This is a Strategic Cruiser heavy fleet, indicating high ISK investment and tactical flexibility. T3 Cruisers can adapt to multiple engagement profiles."
          | insights
        ]
      else
        insights
      end

    # EDENCOM ship analysis
    insights =
      if Map.get(ship_groups, "Precursor Cruiser", 0) > 0 do
        [
          "EDENCOM ships present - these provide unique arc damage that can hit multiple targets simultaneously, excellent against drone/fighter swarms."
          | insights
        ]
      else
        insights
      end

    # Tactical Destroyer analysis
    insights =
      if Map.get(ship_groups, "Tactical Destroyer", 0) > 0 do
        [
          "Tactical Destroyers can switch between defense, speed, and damage modes - highly adaptable for changing battlefield conditions."
          | insights
        ]
      else
        insights
      end

    # Role balance analysis
    logistics_count = Map.get(role_distribution, :logistics, %{}) |> get_role_count()
    flexible_count = Map.get(role_distribution, :flexible, %{}) |> get_role_count()

    insights =
      cond do
        logistics_count == 0 and total_pilots > 5 ->
          ["⚠️ No logistics support detected - fleet vulnerable to attrition warfare." | insights]

        logistics_count > 0 and total_pilots > 0 ->
          logi_ratio = logistics_count / total_pilots

          if logi_ratio > 0.15 do
            [
              "✓ Strong logistics ratio (#{Float.round(logi_ratio * 100, 1)}%) - fleet has good sustainability."
              | insights
            ]
          else
            [
              "Minimal logistics support - suitable for hit-and-run tactics but vulnerable in prolonged engagements."
              | insights
            ]
          end

        true ->
          insights
      end

    # Flexibility analysis
    insights =
      if flexible_count > total_pilots * 0.3 do
        [
          "High tactical flexibility with T3 ships - can adapt doctrine mid-fight based on enemy composition."
          | insights
        ]
      else
        insights
      end

    # Fleet size and ISK assessment
    total_value = Enum.sum(Enum.map(participant_data, &(&1.ship_value || 0)))
    avg_ship_value = if total_pilots > 0, do: total_value / total_pilots, else: 0

    insights =
      cond do
        avg_ship_value > 100_000_000 ->
          [
            "💰 High-value fleet (#{format_isk(avg_ship_value)} avg) - indicates experienced pilots with significant ISK investment."
            | insights
          ]

        avg_ship_value > 50_000_000 ->
          [
            "Moderate investment fleet - good balance of capability and ISK efficiency."
            | insights
          ]

        true ->
          [
            "Cost-effective composition - suitable for volume warfare and learning environments."
            | insights
          ]
      end

    # Cap the insights to top 5 most relevant
    insights |> Enum.take(5)
  end

  defp get_role_count(role_data) when is_map(role_data), do: Map.get(role_data, :count, 0)
  defp get_role_count(_), do: 0

  defp format_isk(amount) when is_number(amount) do
    cond do
      amount >= 1_000_000_000 -> "#{Float.round(amount / 1_000_000_000, 1)}B ISK"
      amount >= 1_000_000 -> "#{Float.round(amount / 1_000_000, 1)}M ISK"
      amount >= 1_000 -> "#{Float.round(amount / 1_000, 1)}K ISK"
      true -> "#{round(amount)} ISK"
    end
  end

  defp format_isk(_), do: "0 ISK"
end
