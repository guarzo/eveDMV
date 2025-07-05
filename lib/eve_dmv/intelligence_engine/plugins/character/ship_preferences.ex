defmodule EveDmv.IntelligenceEngine.Plugins.Character.ShipPreferences do
  @moduledoc """
  Character ship preferences analysis plugin.

  Analyzes individual character ship usage patterns, preferences, and specializations
  including ship roles, fitting patterns, and tactical deployment preferences.
  """

  use EveDmv.IntelligenceEngine.Plugin

  @impl true
  def analyze(character_id, base_data, opts) when is_integer(character_id) do
    start_time = System.monotonic_time()

    try do
      with {:ok, character_stats} <- get_character_data(base_data, character_id),
           {:ok, _killmail_stats} <- get_killmail_stats(base_data, character_id) do
        ship_analysis = %{
          ship_usage_patterns: analyze_ship_usage(character_stats),
          role_specialization: analyze_role_specialization(character_stats),
          fitting_preferences: analyze_fitting_patterns(character_stats),
          deployment_patterns: analyze_deployment_patterns(character_stats),
          ship_value_patterns: analyze_ship_values(character_stats),
          meta_analysis: analyze_meta_usage(character_stats),
          progression_tracking: analyze_ship_progression(character_stats),
          preferences_summary: generate_preferences_summary(character_stats)
        }

        duration_ms =
          System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

        log_plugin_execution(character_id, duration_ms, {:ok, ship_analysis})

        {:ok, ship_analysis}
      else
        {:error, _reason} = error ->
          duration_ms =
            System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

          log_plugin_execution(character_id, duration_ms, error)
          error
      end
    rescue
      exception ->
        handle_plugin_exception(exception, character_id)
    end
  end

  # Batch analysis support
  @impl true
  def analyze(character_ids, base_data, opts) when is_list(character_ids) do
    if supports_batch?() do
      character_ids
      |> Enum.map(fn char_id ->
        Task.async(fn -> {char_id, analyze(char_id, base_data, opts)} end)
      end)
      |> Enum.map(&Task.await(&1, 30_000))
      |> merge_batch_results()
      |> then(&{:ok, &1})
    else
      {:error, :batch_not_supported}
    end
  end

  @impl true
  def plugin_info do
    %{
      name: "Ship Preferences Analyzer",
      description:
        "Analyzes character ship usage patterns, role specialization, and fitting preferences",
      version: "2.0.0",
      dependencies: [:eve_database, :eve_static_data],
      tags: [:character, :ships, :preferences, :fitting],
      author: "EVE DMV Intelligence Team"
    }
  end

  @impl true
  def supports_batch?, do: true

  @impl true
  def dependencies, do: [EveDmv.Database.CharacterRepository, EveDmv.Database.KillmailRepository]

  @impl true
  def cache_strategy do
    %{
      strategy: :default,
      # 10 minutes for ship preferences
      ttl_seconds: 600,
      cache_key_prefix: "ship_preferences"
    }
  end

  # Analysis implementation

  defp analyze_ship_usage(character_stats) do
    ship_usage = character_stats.ship_usage || %{}

    # Calculate total usage across all ships
    total_usage =
      ship_usage
      |> Map.values()
      |> Enum.map(fn ship_data -> Map.get(ship_data, "times_used", 0) end)
      |> Enum.sum()

    # Analyze top ships by usage
    top_ships =
      ship_usage
      |> Enum.map(fn {ship_id, ship_data} ->
        times_used = Map.get(ship_data, "times_used", 0)
        usage_percentage = if total_usage > 0, do: times_used / total_usage, else: 0.0

        %{
          ship_id: ship_id,
          ship_name: Map.get(ship_data, "ship_name", "Unknown"),
          ship_group: Map.get(ship_data, "ship_group", "Unknown"),
          times_used: times_used,
          usage_percentage: usage_percentage,
          avg_ship_value: Map.get(ship_data, "avg_value", 0),
          last_used: Map.get(ship_data, "last_used")
        }
      end)
      |> Enum.sort_by(& &1.usage_percentage, :desc)

    # Calculate specialization metrics
    usage_distribution = Enum.map(top_ships, & &1.usage_percentage)
    specialization_index = calculate_specialization_index(usage_distribution)

    %{
      total_ships_used: map_size(ship_usage),
      total_usage_count: total_usage,
      top_ships: Enum.take(top_ships, 10),
      most_used_ship: List.first(top_ships),
      specialization_index: specialization_index,
      ship_diversity: calculate_ship_diversity(ship_usage),
      usage_concentration: calculate_usage_concentration(usage_distribution)
    }
  end

  defp analyze_role_specialization(character_stats) do
    ship_usage = character_stats.ship_usage || %{}

    # Categorize ships by role
    role_usage =
      ship_usage
      |> Enum.reduce(%{}, fn {_ship_id, ship_data}, acc ->
        ship_group = Map.get(ship_data, "ship_group", "Unknown")
        role = categorize_ship_role(ship_group)
        times_used = Map.get(ship_data, "times_used", 0)

        Map.update(acc, role, times_used, &(&1 + times_used))
      end)

    # Calculate role percentages
    total_role_usage = Enum.sum(Map.values(role_usage))

    role_percentages =
      role_usage
      |> Enum.map(fn {role, usage} ->
        percentage = if total_role_usage > 0, do: usage / total_role_usage, else: 0.0
        {role, %{usage: usage, percentage: percentage}}
      end)
      |> Enum.into(%{})

    # Determine primary and secondary roles
    sorted_roles =
      role_percentages
      |> Enum.sort_by(fn {_role, data} -> data.percentage end, :desc)

    primary_role = sorted_roles |> List.first() |> elem(0)

    secondary_role =
      sorted_roles
      |> Enum.at(1)
      |> case do
        nil -> nil
        {role, _data} -> role
      end

    %{
      role_distribution: role_percentages,
      primary_role: primary_role,
      secondary_role: secondary_role,
      role_specialization_score: calculate_role_specialization(role_percentages),
      role_flexibility: assess_role_flexibility(role_percentages),
      combat_role_focus: determine_combat_focus(role_percentages)
    }
  end

  defp analyze_fitting_patterns(character_stats) do
    ship_usage = character_stats.ship_usage || %{}

    # Analyze common fitting patterns across ships
    fitting_data =
      ship_usage
      |> Enum.flat_map(fn {_ship_id, ship_data} ->
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
    active_systems = character_stats.active_systems || %{}
    ship_usage = character_stats.ship_usage || %{}

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
    ship_usage = character_stats.ship_usage || %{}

    # Calculate ship value statistics
    ship_values =
      ship_usage
      |> Enum.map(fn {_ship_id, ship_data} ->
        Map.get(ship_data, "avg_value", 0)
      end)
      |> Enum.filter(&(&1 > 0))

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
      bling_ratio: calculate_bling_ratio(ship_values)
    }
  end

  defp analyze_meta_usage(character_stats) do
    ship_usage = character_stats.ship_usage || %{}

    # Analyze meta/tech level preferences
    meta_analysis =
      ship_usage
      |> Enum.map(fn {_ship_id, ship_data} ->
        ship_group = Map.get(ship_data, "ship_group", "")
        tech_level = determine_tech_level(ship_group)
        times_used = Map.get(ship_data, "times_used", 0)

        {tech_level, times_used}
      end)
      |> Enum.reduce(%{}, fn {tech_level, usage}, acc ->
        Map.update(acc, tech_level, usage, &(&1 + usage))
      end)

    total_meta_usage = Enum.sum(Map.values(meta_analysis))

    meta_percentages =
      meta_analysis
      |> Enum.map(fn {tech_level, usage} ->
        percentage = if total_meta_usage > 0, do: usage / total_meta_usage, else: 0.0
        {tech_level, percentage}
      end)
      |> Enum.into(%{})

    %{
      tech_level_distribution: meta_percentages,
      prefers_t2: Map.get(meta_percentages, :tech2, 0.0) > 0.3,
      uses_t3: Map.get(meta_percentages, :tech3, 0.0) > 0.0,
      faction_usage: Map.get(meta_percentages, :faction, 0.0),
      meta_progression: assess_meta_progression(meta_percentages)
    }
  end

  defp analyze_ship_progression(character_stats) do
    ship_usage = character_stats.ship_usage || %{}

    # This would ideally analyze progression over time
    # For now, we'll infer progression from current usage patterns

    ship_sizes =
      ship_usage
      |> Enum.reduce(%{}, fn {_ship_id, ship_data}, acc ->
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
    ship_usage = character_stats.ship_usage || %{}

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

  # Helper functions

  defp calculate_specialization_index(usage_distribution) do
    if length(usage_distribution) == 0, do: 0.0

    # Calculate Gini coefficient as specialization measure
    sorted_usage = Enum.sort(usage_distribution)
    n = length(sorted_usage)

    # Complete specialization if only one ship
    if n <= 1, do: 1.0

    sum_products =
      sorted_usage
      |> Enum.with_index(1)
      |> Enum.map(fn {usage, index} -> usage * index end)
      |> Enum.sum()

    mean_usage = Enum.sum(sorted_usage) / n

    gini = 2 * sum_products / (n * n * mean_usage) - (n + 1) / n
    max(0.0, min(1.0, gini))
  end

  defp calculate_ship_diversity(ship_usage) do
    total_ships = map_size(ship_usage)

    case total_ships do
      0 -> 0.0
      1 -> 0.0
      n when n <= 5 -> 0.3
      n when n <= 10 -> 0.6
      n when n <= 20 -> 0.8
      _ -> 1.0
    end
  end

  defp calculate_usage_concentration(usage_distribution) do
    if length(usage_distribution) == 0, do: 1.0

    # Calculate what percentage of usage is in top ship
    max_usage = Enum.max(usage_distribution, fn -> 0.0 end)
    max_usage
  end

  defp categorize_ship_role(ship_group) do
    cond do
      String.contains?(ship_group, ["Battleship", "Dreadnought", "Titan"]) -> :heavy_dps
      String.contains?(ship_group, ["Cruiser", "Destroyer", "Frigate"]) -> :light_dps
      String.contains?(ship_group, ["Logistics", "Logi"]) -> :logistics
      String.contains?(ship_group, ["Interceptor", "Covert"]) -> :tackle
      String.contains?(ship_group, ["Electronic", "ECM"]) -> :ewar
      String.contains?(ship_group, ["Industrial", "Transport"]) -> :industrial
      String.contains?(ship_group, ["Mining"]) -> :mining
      true -> :other
    end
  end

  defp calculate_role_specialization(role_percentages) do
    if map_size(role_percentages) == 0, do: 0.0

    max_percentage =
      role_percentages
      |> Map.values()
      |> Enum.map(& &1.percentage)
      |> Enum.max(fn -> 0.0 end)

    max_percentage
  end

  defp assess_role_flexibility(role_percentages) do
    roles_with_significant_usage =
      role_percentages
      |> Enum.count(fn {_role, data} -> data.percentage > 0.1 end)

    case roles_with_significant_usage do
      0..1 -> :highly_specialized
      2 -> :moderately_flexible
      3 -> :flexible
      _ -> :very_flexible
    end
  end

  defp determine_combat_focus(role_percentages) do
    combat_roles = [:heavy_dps, :light_dps, :tackle, :ewar, :logistics]

    combat_percentage =
      role_percentages
      |> Enum.filter(fn {role, _data} -> role in combat_roles end)
      |> Enum.map(fn {_role, data} -> data.percentage end)
      |> Enum.sum()

    cond do
      combat_percentage > 0.8 -> :combat_focused
      combat_percentage > 0.5 -> :mixed_combat
      combat_percentage > 0.2 -> :some_combat
      true -> :non_combatant
    end
  end

  defp determine_fitting_philosophy(_fitting_data) do
    # Placeholder - would analyze actual fitting data
    :balanced
  end

  defp analyze_meta_preferences(_fitting_data) do
    # Placeholder for meta level analysis
    %{average_meta: 3, prefers_t2: true}
  end

  defp assess_bling_usage(_fitting_data) do
    # Placeholder for expensive module usage analysis
    :moderate
  end

  defp assess_fitting_creativity(_fitting_data) do
    # Placeholder for non-standard fitting analysis
    :standard
  end

  # Placeholder implementations for remaining helper functions
  defp analyze_deployment_contexts(_active_systems, _ship_usage), do: %{}
  defp analyze_security_deployment(_active_systems), do: %{}
  defp identify_home_system_usage(_character_stats), do: %{}
  defp analyze_roaming_with_ships(_character_stats), do: %{}
  defp analyze_ship_rotation(_ship_usage), do: %{}
  defp categorize_ship_values(_ship_values), do: %{}
  defp determine_risk_comfort(_avg_ship_value), do: :moderate
  defp calculate_bling_ratio(_ship_values), do: 0.3
  defp determine_tech_level(_ship_group), do: :tech1
  defp assess_meta_progression(_meta_percentages), do: :progressing
  defp determine_ship_size(_ship_group), do: :medium
  defp flies_capitals?(_character_stats), do: false
  defp determine_subcap_focus(_ship_sizes), do: :balanced
  defp assess_progression_stage(_ship_sizes, _character_stats), do: :intermediate
  defp get_most_used_ship(_ship_usage), do: %{name: "Unknown", usage: 0}
  defp determine_ship_philosophy(_character_stats), do: :practical
  defp determine_pilot_archetype(_character_stats), do: :generalist
  defp identify_ship_strengths(_character_stats), do: ["Versatile"]
  defp identify_ship_weaknesses(_character_stats), do: ["Lacks specialization"]
  defp generate_ship_recommendations(_character_stats), do: ["Consider specializing in a role"]
end
