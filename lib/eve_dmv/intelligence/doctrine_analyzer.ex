defmodule EveDmv.Intelligence.DoctrineAnalyzer do
  @moduledoc """
  Fleet doctrine and ship usage analysis module.

  Analyzes ship usage patterns, doctrine adherence, and fleet composition
  to provide insights into tactical preferences and capabilities.
  """

  require Logger

  @doc """
  Analyze doctrine adherence based on character analysis and fleet data.
  
  Returns analysis of how well a character follows established fleet doctrines
  and their ship usage patterns.
  """
  @spec analyze_doctrine_adherence(map(), map()) :: map()
  def analyze_doctrine_adherence(character_analysis, fleet_data) 
      when is_map(character_analysis) and is_map(fleet_data) do
    
    ship_usage = extract_ship_usage(character_analysis, fleet_data)
    doctrine_patterns = identify_doctrine_patterns(ship_usage)
    adherence_score = calculate_adherence_score(ship_usage, doctrine_patterns)
    
    %{
      ship_diversity: calculate_ship_diversity(ship_usage),
      primary_doctrine: determine_primary_doctrine(ship_usage),
      adherence_score: adherence_score,
      doctrine_patterns: doctrine_patterns,
      tactical_flexibility: assess_tactical_flexibility(ship_usage),
      specialization_level: calculate_specialization_level(ship_usage)
    }
  end

  def analyze_doctrine_adherence(_character_analysis, _fleet_data) do
    %{
      ship_diversity: 0,
      primary_doctrine: :unknown,
      adherence_score: 0,
      doctrine_patterns: %{},
      tactical_flexibility: :low,
      specialization_level: :unknown
    }
  end

  @doc """
  Analyze ship progression consistency for a character.
  
  Examines whether ship usage follows logical progression patterns
  and identifies potential anomalies.
  """
  @spec analyze_ship_progression_consistency(map(), map()) :: map()
  def analyze_ship_progression_consistency(character_analysis, fleet_data)
      when is_map(character_analysis) and is_map(fleet_data) do
    
    ship_timeline = extract_ship_timeline(character_analysis, fleet_data)
    progression_patterns = analyze_progression_patterns(ship_timeline)
    consistency_score = calculate_consistency_score(progression_patterns)
    
    %{
      progression_score: consistency_score,
      progression_patterns: progression_patterns,
      anomalies: detect_progression_anomalies(ship_timeline),
      natural_progression: assess_natural_progression(ship_timeline)
    }
  end

  def analyze_ship_progression_consistency(_character_analysis, _fleet_data) do
    %{
      progression_score: 0,
      progression_patterns: %{},
      anomalies: [],
      natural_progression: false
    }
  end

  @doc """
  Categorize ship types into doctrine categories.
  """
  @spec categorize_ship_doctrine(integer()) :: atom()
  def categorize_ship_doctrine(ship_type_id) when is_integer(ship_type_id) do
    # Simplified ship categorization based on common EVE ship types
    cond do
      ship_type_id in [587, 588, 589] -> :interceptor  # Example interceptor IDs
      ship_type_id in [590, 591, 592] -> :assault_frigate
      ship_type_id in [593, 594, 595] -> :cruiser
      ship_type_id in [596, 597, 598] -> :battlecruiser
      ship_type_id in [599, 600, 601] -> :battleship
      ship_type_id in [602, 603, 604] -> :capital
      true -> :other
    end
  end

  @doc """
  Determine fleet role based on ship usage patterns.
  """
  @spec determine_fleet_role(map()) :: atom()
  def determine_fleet_role(ship_usage) when is_map(ship_usage) do
    # Analyze ship types to determine primary fleet role
    total_usage = Enum.sum(Map.values(ship_usage))
    
    if total_usage == 0 do
      :unknown
    else
      ship_categories = Enum.map(ship_usage, fn {ship_id, count} ->
        {categorize_ship_doctrine(ship_id), count}
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Enum.map(fn {category, counts} -> {category, Enum.sum(counts)} end)
      |> Enum.sort_by(&elem(&1, 1), :desc)
      
      case ship_categories do
        [{primary_category, _} | _] -> primary_category
        [] -> :unknown
      end
    end
  end

  # Private helper functions

  defp extract_ship_usage(character_analysis, fleet_data) do
    # Extract ship usage from analysis data
    ship_data = Map.get(character_analysis, :ship_usage, %{})
    fleet_ships = Map.get(fleet_data, :ships_used, %{})
    
    Map.merge(ship_data, fleet_ships, fn _k, v1, v2 -> v1 + v2 end)
  end

  defp identify_doctrine_patterns(ship_usage) when is_map(ship_usage) do
    ship_categories = Enum.group_by(ship_usage, fn {ship_id, _count} ->
      categorize_ship_doctrine(ship_id)
    end, fn {_ship_id, count} -> count end)
    
    Enum.map(ship_categories, fn {category, counts} ->
      {category, %{
        total_usage: Enum.sum(counts),
        diversity: length(counts),
        consistency: calculate_category_consistency(counts)
      }}
    end)
    |> Enum.into(%{})
  end

  defp calculate_adherence_score(ship_usage, doctrine_patterns) do
    if map_size(ship_usage) == 0 do
      0
    else
      # Base score on doctrine consistency
      primary_doctrine_usage = doctrine_patterns
        |> Map.values()
        |> Enum.map(& &1.total_usage)
        |> Enum.max(fn -> 0 end)
      
      total_usage = Enum.sum(Map.values(ship_usage))
      
      if total_usage > 0 do
        round((primary_doctrine_usage / total_usage) * 100)
      else
        0
      end
    end
  end

  defp calculate_ship_diversity(ship_usage) when is_map(ship_usage) do
    map_size(ship_usage)
  end

  defp determine_primary_doctrine(ship_usage) when is_map(ship_usage) do
    if map_size(ship_usage) == 0 do
      :unknown
    else
      # Find most used ship category
      ship_usage
      |> Enum.group_by(fn {ship_id, _count} -> categorize_ship_doctrine(ship_id) end,
                       fn {_ship_id, count} -> count end)
      |> Enum.map(fn {category, counts} -> {category, Enum.sum(counts)} end)
      |> Enum.max_by(&elem(&1, 1), fn -> {:unknown, 0} end)
      |> elem(0)
    end
  end

  defp assess_tactical_flexibility(ship_usage) when is_map(ship_usage) do
    diversity = calculate_ship_diversity(ship_usage)
    
    cond do
      diversity >= 10 -> :high
      diversity >= 5 -> :medium
      diversity >= 2 -> :low
      true -> :very_low
    end
  end

  defp calculate_specialization_level(ship_usage) when is_map(ship_usage) do
    if map_size(ship_usage) == 0 do
      :unknown
    else
      total_usage = Enum.sum(Map.values(ship_usage))
      max_usage = Enum.max(Map.values(ship_usage))
      
      specialization_ratio = max_usage / total_usage
      
      cond do
        specialization_ratio >= 0.8 -> :highly_specialized
        specialization_ratio >= 0.6 -> :specialized
        specialization_ratio >= 0.4 -> :moderate
        true -> :generalist
      end
    end
  end

  defp extract_ship_timeline(_character_analysis, _fleet_data) do
    # Placeholder for ship timeline extraction
    # Would need timestamp data to build actual timeline
    []
  end

  defp analyze_progression_patterns(ship_timeline) do
    # Placeholder for progression pattern analysis
    if Enum.empty?(ship_timeline) do
      %{pattern: :insufficient_data}
    else
      %{pattern: :normal, confidence: 0.7}
    end
  end

  defp calculate_consistency_score(progression_patterns) do
    case Map.get(progression_patterns, :pattern) do
      :normal -> 85
      :irregular -> 45
      :insufficient_data -> 0
      _ -> 50
    end
  end

  defp detect_progression_anomalies(_ship_timeline) do
    # Placeholder for anomaly detection
    []
  end

  defp assess_natural_progression(_ship_timeline) do
    # Placeholder for natural progression assessment
    true
  end

  defp calculate_category_consistency(counts) when is_list(counts) do
    if length(counts) <= 1 do
      1.0
    else
      variance = Enum.sum(Enum.map(counts, fn count ->
        mean = Enum.sum(counts) / length(counts)
        (count - mean) * (count - mean)
      end)) / length(counts)
      
      # Convert variance to consistency score (0-1)
      max(0.0, 1.0 - variance / 100.0)
    end
  end
end