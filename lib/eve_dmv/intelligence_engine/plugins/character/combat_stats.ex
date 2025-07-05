defmodule EveDmv.IntelligenceEngine.Plugins.Character.CombatStats do
  @moduledoc """
  Character combat statistics analysis plugin.

  Analyzes individual character combat performance including kill/death ratios,
  ISK efficiency, weapon preferences, and engagement patterns. This plugin
  consolidates functionality from the original CharacterAnalyzer module.
  """

  use EveDmv.IntelligenceEngine.Plugin

  @impl true
  def analyze(character_id, base_data, opts) when is_integer(character_id) do
    start_time = System.monotonic_time()

    try do
      with {:ok, character_stats} <- get_character_data(base_data, character_id),
           {:ok, killmail_stats} <- get_killmail_stats(base_data, character_id) do
        combat_analysis = %{
          basic_stats: calculate_basic_stats(character_stats, killmail_stats),
          weapon_analysis: analyze_weapon_preferences(character_stats),
          engagement_patterns: analyze_engagement_patterns(character_stats),
          performance_metrics: calculate_performance_metrics(character_stats, killmail_stats),
          risk_indicators: assess_risk_indicators(character_stats),
          summary: generate_combat_summary(character_stats, killmail_stats)
        }

        duration_ms =
          System.convert_time_unit(System.monotonic_time() - start_time, :native, :millisecond)

        log_plugin_execution(character_id, duration_ms, {:ok, combat_analysis})

        {:ok, combat_analysis}
      else
        {:error, reason} = error ->
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
      # Parallel batch processing for multiple characters
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
      name: "Combat Statistics Analyzer",
      description:
        "Analyzes character combat performance, weapon preferences, and engagement patterns",
      version: "2.0.0",
      dependencies: [:eve_database],
      tags: [:character, :combat, :statistics],
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
      # 5 minutes for combat stats
      ttl_seconds: 300,
      cache_key_prefix: "combat_stats"
    }
  end

  # Analysis implementation

  defp calculate_basic_stats(character_stats, killmail_stats) do
    total_kills = character_stats.total_kills || 0
    total_losses = character_stats.total_losses || 0
    solo_kills = character_stats.solo_kills || 0

    %{
      total_kills: total_kills,
      total_losses: total_losses,
      solo_kills: solo_kills,
      solo_ratio: safe_divide(solo_kills, total_kills),
      kill_death_ratio:
        character_stats.kill_death_ratio || safe_divide(total_kills, max(total_losses, 1)),
      isk_efficiency: character_stats.isk_efficiency || 50.0,
      dangerous_rating: character_stats.dangerous_rating || 3,
      avg_gang_size: character_stats.avg_gang_size || 1.0,
      activity_level: calculate_activity_level(total_kills + total_losses)
    }
  end

  defp analyze_weapon_preferences(character_stats) do
    ship_usage = character_stats.ship_usage || %{}

    # Extract weapon patterns from ship usage data
    weapon_stats =
      ship_usage
      |> Enum.flat_map(fn {_ship_id, ship_data} ->
        common_fits = Map.get(ship_data, "common_fits", [])
        Enum.map(common_fits, fn fit -> Map.get(fit, "weapons", []) end)
      end)
      |> List.flatten()
      |> Enum.frequencies()

    top_weapons =
      weapon_stats
      |> Enum.sort_by(fn {_weapon, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {weapon, count} -> %{weapon: weapon, usage_count: count} end)

    %{
      top_weapons: top_weapons,
      weapon_diversity: map_size(weapon_stats),
      preferred_range: determine_preferred_range(top_weapons),
      weapon_specialization: calculate_weapon_specialization(weapon_stats)
    }
  end

  defp analyze_engagement_patterns(character_stats) do
    active_systems = character_stats.active_systems || %{}
    target_profile = character_stats.target_profile || %{}

    # Analyze geographic patterns
    system_analysis =
      active_systems
      |> Enum.map(fn {system_id, system_data} ->
        %{
          system_id: system_id,
          system_name: Map.get(system_data, "system_name"),
          security: Map.get(system_data, "security"),
          kills: Map.get(system_data, "kills", 0),
          losses: Map.get(system_data, "losses", 0),
          last_seen: Map.get(system_data, "last_seen")
        }
      end)
      |> Enum.sort_by(& &1.kills, :desc)

    # Analyze target preferences
    ship_categories = Map.get(target_profile, "ship_categories", %{})

    preferred_targets =
      ship_categories
      |> Enum.sort_by(fn {_category, data} -> Map.get(data, "killed", 0) end, :desc)
      |> Enum.take(3)

    %{
      favorite_systems: Enum.take(system_analysis, 5),
      security_preferences: analyze_security_preferences(system_analysis),
      target_preferences: preferred_targets,
      avg_victim_gang_size: Map.get(target_profile, "avg_victim_gang_size", 1.0),
      home_system: %{
        id: character_stats.home_system_id,
        name: character_stats.home_system_name
      },
      timezone_activity: character_stats.prime_timezone
    }
  end

  defp calculate_performance_metrics(character_stats, killmail_stats) do
    %{
      aggression_index: character_stats.aggression_index || 0.0,
      efficiency_rating: character_stats.isk_efficiency || 50.0,
      consistency_score: calculate_consistency_score(killmail_stats),
      improvement_trend: calculate_improvement_trend(killmail_stats),
      peer_comparison: calculate_peer_comparison(character_stats),
      specialization_index: calculate_specialization_index(character_stats)
    }
  end

  defp assess_risk_indicators(character_stats) do
    %{
      uses_cynos: character_stats.uses_cynos || false,
      flies_capitals: character_stats.flies_capitals || false,
      has_logi_support: character_stats.has_logi_support || false,
      batphone_probability: character_stats.batphone_probability || "low",
      awox_probability: character_stats.awox_probability || 0.0,
      identified_weaknesses: character_stats.identified_weaknesses || %{},
      threat_level: determine_threat_level(character_stats)
    }
  end

  defp generate_combat_summary(character_stats, killmail_stats) do
    total_activity = (character_stats.total_kills || 0) + (character_stats.total_losses || 0)

    %{
      overall_rating: calculate_overall_rating(character_stats),
      combat_style: determine_combat_style(character_stats),
      experience_level: determine_experience_level(total_activity),
      strengths: identify_strengths(character_stats),
      weaknesses: identify_weaknesses(character_stats),
      recommendations: generate_recommendations(character_stats)
    }
  end

  # Helper functions

  defp safe_divide(numerator, denominator) when denominator > 0, do: numerator / denominator
  defp safe_divide(_, _), do: 0.0

  defp calculate_activity_level(total_activity) do
    cond do
      total_activity > 500 -> :very_active
      total_activity > 100 -> :active
      total_activity > 20 -> :moderate
      total_activity > 5 -> :low
      true -> :inactive
    end
  end

  defp determine_preferred_range(weapons) do
    # Simplified range analysis based on weapon types
    ranges =
      weapons
      |> Enum.map(fn %{weapon: weapon} ->
        cond do
          String.contains?(weapon, ["Blaster", "Pulse"]) -> :short
          String.contains?(weapon, ["Railgun", "Beam"]) -> :long
          String.contains?(weapon, ["Artillery", "Autocannon"]) -> :medium
          true -> :unknown
        end
      end)
      |> Enum.frequencies()

    ranges
    |> Enum.max_by(fn {_range, count} -> count end, fn -> {:unknown, 0} end)
    |> elem(0)
  end

  defp calculate_weapon_specialization(weapon_stats) do
    if map_size(weapon_stats) == 0, do: 0.0

    total_usage = Enum.sum(Map.values(weapon_stats))
    max_usage = Enum.max(Map.values(weapon_stats), fn -> 0 end)

    max_usage / total_usage
  end

  defp analyze_security_preferences(system_analysis) do
    security_kills =
      system_analysis
      |> Enum.group_by(fn system ->
        case system.security do
          sec when sec >= 0.5 -> :highsec
          sec when sec > 0.0 -> :lowsec
          _ -> :nullsec
        end
      end)
      |> Enum.map(fn {sec_type, systems} ->
        total_kills = Enum.sum(Enum.map(systems, & &1.kills))
        {sec_type, total_kills}
      end)
      |> Enum.into(%{})

    total_kills = Enum.sum(Map.values(security_kills))

    security_kills
    |> Enum.map(fn {sec_type, kills} ->
      {sec_type, if(total_kills > 0, do: kills / total_kills, else: 0.0)}
    end)
    |> Enum.into(%{})
  end

  defp calculate_consistency_score(_killmail_stats) do
    # Placeholder - would analyze killmail patterns for consistency
    0.75
  end

  defp calculate_improvement_trend(_killmail_stats) do
    # Placeholder - would analyze performance over time
    :stable
  end

  defp calculate_peer_comparison(_character_stats) do
    # Placeholder - would compare against similar characters
    %{percentile: 65, category: :above_average}
  end

  defp calculate_specialization_index(character_stats) do
    ship_usage = character_stats.ship_usage || %{}

    if map_size(ship_usage) == 0, do: 0.0

    total_usage =
      ship_usage
      |> Map.values()
      |> Enum.map(fn ship_data -> Map.get(ship_data, "times_used", 0) end)
      |> Enum.sum()

    max_usage =
      ship_usage
      |> Map.values()
      |> Enum.map(fn ship_data -> Map.get(ship_data, "times_used", 0) end)
      |> Enum.max(fn -> 0 end)

    if total_usage > 0, do: max_usage / total_usage, else: 0.0
  end

  defp determine_threat_level(character_stats) do
    rating = character_stats.dangerous_rating || 3

    case rating do
      5 -> :extreme
      4 -> :high
      3 -> :medium
      2 -> :low
      _ -> :minimal
    end
  end

  defp calculate_overall_rating(character_stats) do
    # Composite score based on multiple factors
    base_score = (character_stats.dangerous_rating || 3) * 20
    efficiency_bonus = (character_stats.isk_efficiency || 50) / 10

    min(100, base_score + efficiency_bonus)
  end

  defp determine_combat_style(character_stats) do
    solo_ratio = safe_divide(character_stats.solo_kills || 0, character_stats.total_kills || 1)
    avg_gang_size = character_stats.avg_gang_size || 1.0

    cond do
      solo_ratio > 0.7 -> :solo_hunter
      avg_gang_size > 10 -> :fleet_warrior
      avg_gang_size > 3 -> :small_gang
      true -> :mixed
    end
  end

  defp determine_experience_level(total_activity) do
    cond do
      total_activity > 1000 -> :veteran
      total_activity > 200 -> :experienced
      total_activity > 50 -> :intermediate
      total_activity > 10 -> :novice
      true -> :rookie
    end
  end

  defp identify_strengths(character_stats) do
    strengths = []

    strengths =
      if (character_stats.isk_efficiency || 50) > 75,
        do: ["High ISK efficiency" | strengths],
        else: strengths

    strengths =
      if (character_stats.kill_death_ratio || 1) > 3,
        do: ["Excellent K/D ratio" | strengths],
        else: strengths

    strengths =
      if (character_stats.dangerous_rating || 3) >= 4,
        do: ["High threat level" | strengths],
        else: strengths

    strengths
  end

  defp identify_weaknesses(character_stats) do
    weaknesses = character_stats.identified_weaknesses || %{}

    Map.get(weaknesses, "behavioral", []) ++
      Map.get(weaknesses, "technical", []) ++
      Map.get(weaknesses, "common_mistakes", [])
  end

  defp generate_recommendations(character_stats) do
    recommendations = []

    efficiency = character_stats.isk_efficiency || 50

    recommendations =
      if efficiency < 40,
        do: ["Focus on target selection to improve ISK efficiency" | recommendations],
        else: recommendations

    solo_kills = character_stats.solo_kills || 0
    total_kills = character_stats.total_kills || 1
    solo_ratio = solo_kills / total_kills

    recommendations =
      if solo_ratio < 0.1,
        do: ["Consider practicing solo PvP to improve individual skills" | recommendations],
        else: recommendations

    recommendations
  end
end
