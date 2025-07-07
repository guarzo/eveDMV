defmodule EveDmv.Contexts.FleetOperations.Analyzers.CompositionAnalyzer do
  @moduledoc """
  Fleet composition analysis for tactical assessment and optimization.

  Analyzes fleet compositions including ship roles, balance assessment,
  tactical capabilities, and effectiveness ratings. Provides insights
  into fleet strengths, weaknesses, and optimization opportunities.
  """

  use EveDmv.ErrorHandler
  alias EveDmv.Contexts.FleetOperations.Infrastructure.FleetRepository
  alias EveDmv.Result
  alias EveDmv.Shared.ShipDatabaseService

  @doc """
  Analyze fleet composition for effectiveness and tactical balance.
  """
  def analyze(fleet_id, base_data \\ %{}, opts \\ []) when is_integer(fleet_id) do
    try do
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
    ship_composition =
      participant_data
      |> Enum.group_by(fn participant ->
        participant.ship_group || "Unknown"
      end)
      |> Enum.map(fn {ship_group, participants} ->
        {ship_group,
         %{
           count: length(participants),
           percentage: safe_divide(length(participants), length(participant_data)) * 100,
           total_value: Enum.sum(Enum.map(participants, &(&1.ship_value || 0))),
           ships:
             Enum.map(participants, fn p ->
               %{
                 character_name: p.character_name,
                 ship_type: p.ship_type,
                 ship_value: p.ship_value
               }
             end)
         }}
      end)
      |> Enum.into(%{})

    most_common_ships =
      Enum.sort_by(ship_composition, fn {_group, data} -> data.count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {group, data} ->
        %{ship_group: group, count: data.count, percentage: data.percentage}
      end)

    diversity_index = calculate_ship_diversity(ship_composition)

    %{
      ship_breakdown: ship_composition,
      most_common_ships: most_common_ships,
      unique_ship_types: map_size(ship_composition),
      diversity_index: diversity_index,
      composition_balance: assess_composition_balance(ship_composition)
    }
  end

  defp analyze_role_distribution(participant_data) do
    role_distribution =
      participant_data
      |> Enum.group_by(fn participant ->
        categorize_ship_role(participant.ship_group || "Unknown")
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
      analysis_confidence: calculate_analysis_confidence(participant_data)
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
  defp assess_role_balance(_role_distribution), do: 75.0
  defp identify_missing_roles(_role_distribution), do: [:logistics, :ewar]
  defp analyze_damage_capabilities(_participant_data), do: %{rating: :good, estimated_dps: 15_000}
  defp analyze_ewar_capabilities(_participant_data), do: %{rating: :moderate, jam_strength: 5}
  defp analyze_logistics_capabilities(_participant_data), do: %{rating: :weak, rep_power: 2000}
  defp analyze_mobility_capabilities(_participant_data), do: %{rating: :good, avg_speed: 2500}
  defp analyze_range_capabilities(_participant_data), do: %{optimal: :medium, falloff: :good}
  defp calculate_tactical_rating(_participant_data), do: 70.0
  defp assess_role_balance_detailed(_role_distribution), do: 75.0
  defp assess_ship_size_balance(_participant_data), do: 80.0
  defp assess_value_distribution(_participant_data), do: 60.0
  defp assess_experience_distribution(_participant_data), do: 70.0
  defp calculate_overall_balance_score(scores), do: Enum.sum(scores) / length(scores)

  defp generate_balance_recommendations(_role_distribution),
    do: ["Add logistics support", "Improve EWAR coverage"]

  defp calculate_estimated_dps(_participant_data), do: 15_000
  defp calculate_alpha_strike_potential(_participant_data), do: 50_000
  defp calculate_effective_hp(_participant_data), do: 2_500_000
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
end
