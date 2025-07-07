defmodule EveDmv.Contexts.PlayerProfile.Analyzers.ShipPreferencesAnalyzer do
  @moduledoc """
  Ship preferences analyzer for player profiles.

  Analyzes individual character ship usage patterns, preferences, and specializations
  including ship roles, fitting patterns, and tactical deployment preferences.
  """

  use EveDmv.ErrorHandler

  alias EveDmv.Result
  alias EveDmv.Shared.ShipAnalysis

  require Logger

  @doc """
  Analyze ship preferences for a character.
  """
  @spec analyze(integer(), map()) :: Result.t(map())
  def analyze(character_id, base_data \\ %{}) when is_integer(character_id) do
    character_stats = Map.get(base_data, :character_stats, %{})

    ship_analysis = %{
      ship_usage_patterns: ShipAnalysis.analyze_ship_usage(character_stats),
      role_specialization: ShipAnalysis.analyze_role_specialization(character_stats),
      fitting_preferences: analyze_fitting_patterns(character_stats),
      deployment_patterns: analyze_deployment_patterns(character_stats),
      ship_value_patterns: analyze_ship_values(character_stats),
      meta_analysis: analyze_meta_usage(character_stats),
      progression_tracking: analyze_ship_progression(character_stats),
      preferences_summary: generate_preferences_summary(character_stats),
      diversity_metrics: calculate_diversity_metrics(character_stats),
      specialization: calculate_specialization_metrics(character_stats)
    }

    Result.ok(ship_analysis)
  rescue
    exception ->
      Logger.error("Ship preferences analysis failed",
        character_id: character_id,
        error: Exception.format(:error, exception)
      )

      Result.error(:analysis_failed, "Ship preferences analysis error: #{inspect(exception)}")
  end

  # Core analysis functions

  # Ship usage analysis delegated to shared module
  # This function is now handled by ShipAnalysis.analyze_ship_usage/1

  # Role specialization analysis delegated to shared module
  # This function is now handled by ShipAnalysis.analyze_role_specialization/1

  defp analyze_fitting_patterns(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    # Analyze common fitting patterns across ships
    fitting_data =
      Enum.flat_map(ship_usage, fn {_ship_id, ship_data} ->
        Map.get(ship_data, "common_fits", [])
      end)

    # Extract weapon patterns
    weapon_patterns =
      fitting_data
      |> Enum.flat_map(fn fit -> Map.get(fit, "weapons", []) end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_weapon, count} -> count end, :desc)
      |> Enum.take(5)

    # Extract module patterns
    module_patterns =
      fitting_data
      |> Enum.flat_map(fn fit -> Map.get(fit, "modules", []) end)
      |> Enum.frequencies()
      |> Enum.sort_by(fn {_module, count} -> count end, :desc)
      |> Enum.take(10)

    # Analyze fitting philosophy
    fitting_philosophy = determine_fitting_philosophy(fitting_data)

    %{
      common_weapons: weapon_patterns,
      common_modules: module_patterns,
      fitting_philosophy: fitting_philosophy,
      meta_level_preference: analyze_meta_preferences(fitting_data),
      bling_tendency: assess_bling_usage(fitting_data),
      fitting_creativity: assess_fitting_creativity(fitting_data)
    }
  end

  defp analyze_deployment_patterns(character_stats) do
    active_systems = Map.get(character_stats, :active_systems, %{})
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    # Analyze where different ships are used
    deployment_contexts = analyze_deployment_contexts(active_systems, ship_usage)

    # Analyze security space preferences by ship type
    security_deployment = analyze_security_deployment(active_systems)

    %{
      deployment_contexts: deployment_contexts,
      security_space_usage: security_deployment,
      home_system_ships: identify_home_system_usage(character_stats),
      roaming_patterns: analyze_roaming_with_ships(character_stats),
      ship_rotation_patterns: analyze_ship_rotation(ship_usage)
    }
  end

  defp analyze_ship_values(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    # Calculate ship value statistics
    ship_values =
      for {_ship_id, ship_data} <- ship_usage,
          avg_value = Map.get(ship_data, "avg_value", 0),
          avg_value > 0,
          do: avg_value

    avg_ship_value =
      if length(ship_values) > 0, do: Enum.sum(ship_values) / length(ship_values), else: 0

    max_ship_value = Enum.max(ship_values, fn -> 0 end)
    min_ship_value = Enum.min(ship_values, fn -> 0 end)

    # Categorize value preferences
    value_brackets = categorize_ship_values(ship_values)

    %{
      average_ship_value: avg_ship_value,
      max_ship_value: max_ship_value,
      min_ship_value: min_ship_value,
      value_range: max_ship_value - min_ship_value,
      value_bracket_distribution: value_brackets,
      risk_comfort_level: determine_risk_comfort(avg_ship_value),
      bling_ratio: calculate_bling_ratio(ship_values),
      flies_expensive_ships: avg_ship_value > 500_000_000
    }
  end

  defp analyze_meta_usage(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    # Analyze meta/tech level preferences
    meta_analysis =
      Enum.reduce(
        Enum.map(ship_usage, fn {_ship_id, ship_data} ->
          ship_group = Map.get(ship_data, "ship_group", "")
          tech_level = determine_tech_level(ship_group)
          times_used = Map.get(ship_data, "times_used", 0)

          {tech_level, times_used}
        end),
        %{},
        fn {tech_level, usage}, acc ->
          Map.update(acc, tech_level, usage, &(&1 + usage))
        end
      )

    total_meta_usage = Enum.sum(Map.values(meta_analysis))

    meta_percentages =
      Enum.into(
        Enum.map(meta_analysis, fn {tech_level, usage} ->
          percentage = if total_meta_usage > 0, do: usage / total_meta_usage, else: 0.0
          {tech_level, percentage}
        end),
        %{}
      )

    %{
      tech_level_distribution: meta_percentages,
      prefers_t2: Map.get(meta_percentages, :tech2, 0.0) > 0.3,
      uses_t3: Map.get(meta_percentages, :tech3, 0.0) > 0.0,
      faction_usage: Map.get(meta_percentages, :faction, 0.0),
      meta_progression: assess_meta_progression(meta_percentages)
    }
  end

  defp analyze_ship_progression(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    # This would ideally analyze progression over time
    # For now, we'll infer progression from current usage patterns

    ship_sizes =
      Enum.reduce(ship_usage, %{}, fn {_ship_id, ship_data}, acc ->
        ship_group = Map.get(ship_data, "ship_group", "")
        size = determine_ship_size(ship_group)
        times_used = Map.get(ship_data, "times_used", 0)

        Map.update(acc, size, times_used, &(&1 + times_used))
      end)

    %{
      ship_size_progression: ship_sizes,
      capital_qualified: flies_capitals?(character_stats),
      subcap_specialization: determine_subcap_focus(ship_sizes),
      progression_stage: assess_progression_stage(ship_sizes, character_stats)
    }
  end

  defp generate_preferences_summary(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    # Generate high-level insights
    primary_ship = get_most_used_ship(ship_usage)
    ship_philosophy = determine_ship_philosophy(character_stats)

    %{
      signature_ship: primary_ship,
      ship_philosophy: ship_philosophy,
      pilot_archetype: determine_pilot_archetype(character_stats),
      strengths: identify_ship_strengths(character_stats),
      potential_weaknesses: identify_ship_weaknesses(character_stats),
      recommendations: generate_ship_recommendations(character_stats)
    }
  end

  defp calculate_diversity_metrics(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    total_ships = map_size(ship_usage)
    ship_diversity_index = calculate_ship_diversity_index(ship_usage)

    %{
      total_unique_ships: total_ships,
      ship_diversity_index: ship_diversity_index,
      diversity_level: classify_diversity_level(ship_diversity_index),
      specialization_vs_diversity: balance_score(ship_diversity_index)
    }
  end

  defp calculate_specialization_metrics(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    usage_values =
      ship_usage
      |> Map.values()
      |> Enum.map(&Map.get(&1, "times_used", 0))

    specialization_score = calculate_specialization_score(usage_values)

    %{
      specialization_score: specialization_score,
      level: classify_specialization_level(specialization_score),
      top_ship_dominance: calculate_top_ship_dominance(ship_usage),
      role_focus_strength: calculate_role_focus_strength(character_stats)
    }
  end

  # Helper functions

  # Specialization index calculation delegated to shared module
  defp calculate_specialization_index(usage_distribution) do
    ShipAnalysis.calculate_specialization_index(usage_distribution)
  end

  # Ship diversity calculation delegated to shared module
  defp calculate_ship_diversity(ship_usage) do
    ShipAnalysis.calculate_ship_diversity(ship_usage)
  end

  defp calculate_ship_diversity_index(ship_usage) do
    if map_size(ship_usage) == 0, do: 0.0

    # Calculate total usage first
    total_usage =
      ship_usage
      |> Map.values()
      |> Enum.reduce(0, fn ship_data, acc ->
        usage = Map.get(ship_data, "times_used", 0)
        acc + usage
      end)

    if total_usage == 0, do: 0.0

    # Calculate Shannon diversity index
    shannon_diversity =
      ship_usage
      |> Map.values()
      |> Enum.reduce(0.0, fn ship_data, acc ->
        usage = Map.get(ship_data, "times_used", 0)

        if usage > 0 do
          proportion = usage / total_usage
          acc + -proportion * :math.log(proportion)
        else
          acc
        end
      end)

    # Normalize to 0-1 range
    max_diversity = :math.log(map_size(ship_usage))
    if max_diversity > 0, do: shannon_diversity / max_diversity, else: 0
  end

  # Usage concentration calculation delegated to shared module
  defp calculate_usage_concentration(usage_distribution) do
    ShipAnalysis.calculate_usage_concentration(usage_distribution)
  end

  # Ship role categorization delegated to shared module
  defp categorize_ship_role(ship_group) do
    ShipAnalysis.categorize_ship_role(ship_group)
  end

  # Role specialization calculation delegated to shared module
  defp calculate_role_specialization(role_percentages) do
    ShipAnalysis.calculate_role_specialization(role_percentages)
  end

  # Role flexibility assessment delegated to shared module
  defp assess_role_flexibility(role_percentages) do
    ShipAnalysis.assess_role_flexibility(role_percentages)
  end

  # Combat focus determination delegated to shared module
  defp determine_combat_focus(role_percentages) do
    ShipAnalysis.determine_combat_focus(role_percentages)
  end

  # Simplified helper functions that return basic values

  defp determine_fitting_philosophy(_fitting_data), do: :unknown
  defp analyze_meta_preferences(_fitting_data), do: %{}
  defp assess_bling_usage(_fitting_data), do: :unknown
  defp assess_fitting_creativity(_fitting_data), do: :unknown

  defp analyze_deployment_contexts(active_systems, ship_usage) do
    if map_size(active_systems) == 0 or map_size(ship_usage) == 0 do
      %{}
    else
      %{
        context_inference: "based_on_ship_types",
        deployment_patterns: []
      }
    end
  end

  defp analyze_security_deployment(active_systems) do
    if map_size(active_systems) == 0 do
      %{}
    else
      %{
        primary_operating_space: :unknown,
        security_diversity: :unknown
      }
    end
  end

  defp identify_home_system_usage(_character_stats), do: %{}
  defp analyze_roaming_with_ships(_character_stats), do: %{}
  defp analyze_ship_rotation(_ship_usage), do: %{}

  # Ship value categorization delegated to shared module
  defp categorize_ship_values(ship_values) do
    ShipAnalysis.categorize_ship_values(ship_values)
  end

  # Risk comfort determination delegated to shared module
  defp determine_risk_comfort(avg_ship_value) do
    ShipAnalysis.determine_risk_comfort(avg_ship_value)
  end

  # Bling ratio calculation delegated to shared module
  defp calculate_bling_ratio(ship_values) do
    ShipAnalysis.calculate_bling_ratio(ship_values)
  end

  # Tech level determination delegated to shared module
  defp determine_tech_level(ship_group) do
    ShipAnalysis.determine_tech_level(ship_group)
  end

  defp assess_meta_progression(_meta_percentages), do: :unknown

  # Ship size determination delegated to shared module
  defp determine_ship_size(ship_group) do
    ShipAnalysis.determine_ship_size(ship_group)
  end

  # Capital ship detection delegated to shared module
  defp flies_capitals?(character_stats) do
    ShipAnalysis.flies_capitals?(character_stats)
  end

  defp determine_subcap_focus(_ship_sizes), do: :unknown
  defp assess_progression_stage(_ship_sizes, _character_stats), do: :unknown

  # Most used ship detection delegated to shared module
  defp get_most_used_ship(ship_usage) do
    ShipAnalysis.get_most_used_ship(ship_usage)
  end

  defp determine_ship_philosophy(_character_stats), do: :unknown
  defp determine_pilot_archetype(_character_stats), do: :unknown
  defp identify_ship_strengths(_character_stats), do: []
  defp identify_ship_weaknesses(_character_stats), do: []
  defp generate_ship_recommendations(_character_stats), do: []

  defp classify_diversity_level(diversity_index) do
    cond do
      diversity_index > 0.8 -> :very_high
      diversity_index > 0.6 -> :high
      diversity_index > 0.4 -> :moderate
      diversity_index > 0.2 -> :low
      true -> :very_low
    end
  end

  defp balance_score(diversity_index) do
    # Balance between specialization (low diversity) and flexibility (high diversity)
    # Optimal balance around 0.6
    optimal = 0.6
    1.0 - abs(diversity_index - optimal) / optimal
  end

  defp calculate_specialization_score(usage_values) do
    if Enum.empty?(usage_values), do: 0.0

    total_usage = Enum.sum(usage_values)
    if total_usage == 0, do: 0.0

    max_usage = Enum.max(usage_values)
    max_usage / total_usage
  end

  defp classify_specialization_level(specialization_score) do
    cond do
      specialization_score > 0.8 -> :highly_specialized
      specialization_score > 0.6 -> :specialized
      specialization_score > 0.4 -> :moderately_specialized
      specialization_score > 0.2 -> :diversified
      true -> :highly_diversified
    end
  end

  defp calculate_top_ship_dominance(ship_usage) do
    if map_size(ship_usage) == 0, do: 0.0

    usage_values =
      ship_usage
      |> Map.values()
      |> Enum.map(&Map.get(&1, "times_used", 0))

    total_usage = Enum.sum(usage_values)

    if total_usage == 0, do: 0.0

    max_usage = Enum.max(usage_values)
    max_usage / total_usage
  end

  defp calculate_role_focus_strength(character_stats) do
    ship_usage = Map.get(character_stats, :ship_usage, %{})

    if map_size(ship_usage) == 0, do: 0.0

    # Calculate how focused the character is on specific roles
    role_usage =
      Enum.reduce(ship_usage, %{}, fn {_ship_id, ship_data}, acc ->
        ship_group = Map.get(ship_data, "ship_group", "Unknown")
        role = categorize_ship_role(ship_group)
        times_used = Map.get(ship_data, "times_used", 0)
        Map.update(acc, role, times_used, &(&1 + times_used))
      end)

    total_role_usage = Enum.sum(Map.values(role_usage))

    if total_role_usage == 0, do: 0.0

    max_role_usage = Enum.max(Map.values(role_usage))
    max_role_usage / total_role_usage
  end
end
