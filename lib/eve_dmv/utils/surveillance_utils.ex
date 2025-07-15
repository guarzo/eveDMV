defmodule EveDmv.Utils.SurveillanceUtils do
  @moduledoc """
  Utility functions for surveillance and threat analysis.

  Extracted from ChainIntelligenceHelper to improve code organization and reusability.
  Contains helper functions for:
  - Threat level calculations
  - Ship analysis and classification
  - Data confidence assessment
  - Statistical calculations
  """

  require Logger

  @doc """
  Calculate threat level based on multiple factors.
  """
  def calculate_threat_level(hostile_count, hostile_ships, recent_activity, context) do
    # Base threat calculation
    base_threat =
      cond do
        hostile_count >= 10 -> :critical
        hostile_count >= 5 -> :high
        hostile_count >= 2 -> :medium
        hostile_count >= 1 -> :low
        true -> :minimal
      end

    # Adjust based on ship types and recent activity
    ship_threat = analyze_ship_threat(hostile_ships)
    activity_threat = if length(recent_activity) > 3, do: 1, else: 0
    context_threat = Map.get(context || %{}, :escalation_factor, 0)

    # Escalate threat level if needed
    case {base_threat, ship_threat + activity_threat + context_threat} do
      {:minimal, factor} when factor >= 2 -> :low
      {:low, factor} when factor >= 2 -> :medium
      {:medium, factor} when factor >= 2 -> :high
      {:high, factor} when factor >= 1 -> :critical
      {level, _} -> level
    end
  end

  @doc """
  Analyze ship threat level based on ship composition.
  """
  def analyze_ship_threat(ships) when is_list(ships) do
    # Count dangerous ship types
    dangerous_ships =
      Enum.count(ships, fn ship ->
        ship_name = Map.get(ship, "name", "") |> String.downcase()
        ship_name =~ ~r/(dread|carrier|super|titan|recon|interceptor|dictor)/
      end)

    if dangerous_ships > 0, do: 2, else: 0
  end

  def analyze_ship_threat(_), do: 0

  @doc """
  Calculate confidence level based on data quality.
  """
  def calculate_confidence(hostile_data, contact_info, recent_activity) do
    # Base confidence from data quality
    data_quality = if is_map(hostile_data) and map_size(hostile_data) > 2, do: 0.4, else: 0.2
    contact_quality = if is_map(contact_info) and map_size(contact_info) > 0, do: 0.3, else: 0.1
    activity_confirmation = if length(recent_activity) > 0, do: 0.3, else: 0.0

    min(1.0, data_quality + contact_quality + activity_confirmation)
  end

  @doc """
  Generate threat-based recommendations.
  """
  def generate_recommendations(threat_level, _hostile_count, context) do
    base_actions =
      case threat_level do
        :critical -> [:immediate_evacuation, :alert_all, :request_backup, :avoid_system]
        :high -> [:alert_members, :prepare_evacuation, :increase_intel, :avoid_solo_ops]
        :medium -> [:monitor_closely, :alert_members, :safe_up_if_solo]
        :low -> [:monitor, :share_intel]
        :minimal -> [:note_activity]
      end

    # Add context-specific actions
    context_actions =
      case Map.get(context || %{}, :operation_type) do
        :mining -> [:recall_miners, :secure_ore]
        :ratting -> [:recall_ratters, :dock_up]
        :exploration -> [:safe_up_explorers]
        _ -> []
      end

    Enum.uniq(base_actions ++ context_actions)
  end

  @doc """
  Classify inhabitants as hostile or friendly.
  """
  def classify_inhabitants(inhabitants) when is_list(inhabitants) do
    # Simple classification based on known patterns
    # In a real implementation, this would check against standings, known hostile lists, etc.
    Enum.filter(inhabitants, fn inhabitant ->
      name = Map.get(inhabitant, "name", "") |> String.downcase()
      corp = Map.get(inhabitant, "corporation", "") |> String.downcase()

      # Check for known hostile patterns (simplified)
      name =~ ~r/(hostile|enemy|pirate)/ or corp =~ ~r/(pirate|hostile)/
    end)
  end

  def classify_inhabitants(_), do: []

  @doc """
  Determine system threat level based on inhabitants and recent activity.
  """
  def determine_system_threat_level(hostile_count, recent_kill_count, _inhabitants) do
    cond do
      hostile_count >= 5 or recent_kill_count >= 5 -> :critical
      hostile_count >= 3 or recent_kill_count >= 3 -> :high
      hostile_count >= 1 or recent_kill_count >= 1 -> :medium
      true -> :low
    end
  end

  @doc """
  Calculate various risk factors for threat assessment.
  """
  def calculate_risk_factors(hostile_inhabitants, recent_kills, inhabitants) do
    %{
      hostile_ratio:
        if(length(inhabitants) > 0,
          do: length(hostile_inhabitants) / length(inhabitants),
          else: 0
        ),
      recent_violence: length(recent_kills),
      escalation_potential: calculate_escalation_potential(hostile_inhabitants, recent_kills),
      evacuation_difficulty: calculate_evacuation_difficulty(inhabitants)
    }
  end

  @doc """
  Calculate escalation potential based on hostiles and activity.
  """
  def calculate_escalation_potential(hostiles, recent_kills) do
    # Simple escalation calculation
    base = length(hostiles) * 0.2
    activity = length(recent_kills) * 0.1
    min(1.0, base + activity)
  end

  @doc """
  Calculate evacuation difficulty based on number of friendlies.
  """
  def calculate_evacuation_difficulty(inhabitants) do
    # Difficulty based on number of friendlies to evacuate
    case length(inhabitants) do
      n when n >= 10 -> 0.9
      n when n >= 5 -> 0.6
      n when n >= 2 -> 0.3
      _ -> 0.1
    end
  end

  @doc """
  Extract hostile ships from hostile data.
  """
  def extract_hostile_ships(hostile_data) when is_map(hostile_data) do
    ships = Map.get(hostile_data, "ships", []) || Map.get(hostile_data, :ships, [])
    if is_list(ships), do: ships, else: []
  end

  def extract_hostile_ships(_), do: []

  @doc """
  Group items by a specified key (supports both string and atom keys).
  """
  def group_by_system(items, key \\ "system_id")

  def group_by_system(items, key) when is_list(items) do
    Enum.group_by(items, fn item ->
      case item do
        %{} -> Map.get(item, key) || Map.get(item, String.to_existing_atom(key))
        _ -> nil
      end
    end)
  end

  def group_by_system(_, _), do: %{}

  @doc """
  Convert threat level atoms to numeric values for calculations.
  """
  def threat_level_to_number(%{threat_level: level}) do
    case level do
      :critical -> 4
      :high -> 3
      :medium -> 2
      :low -> 1
      _ -> 0
    end
  end

  def threat_level_to_number(level) when is_atom(level) do
    case level do
      :critical -> 4
      :high -> 3
      :medium -> 2
      :low -> 1
      _ -> 0
    end
  end

  def threat_level_to_number(_), do: 0

  @doc """
  Calculate simple linear trend from a list of numbers.
  """
  def calculate_trend(numbers) when length(numbers) < 2, do: 0

  def calculate_trend(numbers) do
    # Simple linear trend calculation
    indexed = Enum.with_index(numbers)
    sum_x = Enum.sum(0..(length(numbers) - 1))
    sum_y = Enum.sum(numbers)
    sum_xy = Enum.sum(for {y, x} <- indexed, do: x * y)
    sum_x2 = Enum.sum(for x <- 0..(length(numbers) - 1), do: x * x)

    n = length(numbers)

    if n * sum_x2 - sum_x * sum_x == 0 do
      0
    else
      (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x)
    end
  end

  @doc """
  Calculate activity trend based on recent vs older activity.
  """
  def calculate_activity_trend(recent_activity) do
    if length(recent_activity) < 2 do
      :insufficient_data
    else
      # Compare recent vs older activity
      now = DateTime.utc_now()
      # Last 2 hours
      recent_cutoff = DateTime.add(now, -2 * 3600, :second)

      recent_count =
        Enum.count(recent_activity, fn %{killmail_time: time} ->
          DateTime.compare(time, recent_cutoff) != :lt
        end)

      older_count = length(recent_activity) - recent_count

      cond do
        recent_count > older_count * 2 -> :increasing
        recent_count * 2 < older_count -> :decreasing
        true -> :stable
      end
    end
  end

  @doc """
  Analyze threat escalation patterns from historical data.
  """
  def analyze_threat_escalation(threat_history) do
    if length(threat_history) < 2 do
      :no_data
    else
      # Check if threat levels are escalating
      recent_threats =
        threat_history
        |> Enum.take(5)
        |> Enum.map(&threat_level_to_number/1)

      trend = calculate_trend(recent_threats)

      cond do
        trend > 0.5 -> :escalating
        trend < -0.5 -> :de_escalating
        true -> :stable
      end
    end
  end

  @doc """
  Identify systems with high activity (hotspots).
  """
  def identify_hotspot_systems(recent_activity) do
    recent_activity
    |> Enum.group_by(& &1.system_id)
    |> Enum.map(fn {system_id, activities} ->
      {system_id, length(activities)}
    end)
    |> Enum.filter(fn {_, count} -> count >= 3 end)
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {system_id, _} -> system_id end)
  end

  @doc """
  Calculate threat frequency (threats per day).
  """
  def calculate_threat_frequency(threat_history) do
    if Enum.empty?(threat_history) do
      0.0
    else
      # Calculate threats per day
      now = DateTime.utc_now()

      oldest_threat =
        threat_history
        |> Enum.map(& &1.detected_at)
        |> Enum.min_by(&DateTime.to_unix/1, DateTime)

      days_span = max(1, DateTime.diff(now, oldest_threat, :day))
      length(threat_history) / days_span
    end
  end

  @doc """
  Calculate overall chain threat level from system threats and patterns.
  """
  def calculate_overall_chain_threat(system_threats, chain_patterns) do
    # Get highest system threat
    max_system_threat =
      system_threats
      |> Enum.map(&Map.get(&1, :threat_level, :low))
      |> Enum.map(&threat_level_to_number/1)
      |> Enum.max(&>=/2, fn -> 1 end)

    # Factor in chain patterns
    pattern_modifier =
      case chain_patterns do
        %{activity_trend: :increasing, threat_escalation: :escalating} -> 1
        %{activity_trend: :increasing} -> 0.5
        %{threat_escalation: :escalating} -> 0.5
        _ -> 0
      end

    final_threat = max_system_threat + pattern_modifier

    cond do
      final_threat >= 4 -> :critical
      final_threat >= 3 -> :high
      final_threat >= 2 -> :medium
      final_threat >= 1 -> :low
      true -> :minimal
    end
  end

  @doc """
  Calculate analysis confidence based on data quality.
  """
  def calculate_analysis_confidence(chain_data) do
    # Base confidence from data availability
    topology_quality = if map_size(chain_data.topology) > 0, do: 0.3, else: 0.0
    inhabitants_quality = if length(chain_data.inhabitants) > 0, do: 0.3, else: 0.1
    activity_quality = if length(chain_data.recent_activity) > 0, do: 0.3, else: 0.1
    history_quality = if length(chain_data.threat_history) > 0, do: 0.1, else: 0.0

    min(1.0, topology_quality + inhabitants_quality + activity_quality + history_quality)
  end

  @doc """
  Assess data quality for analysis reporting.
  """
  def assess_data_quality(chain_data) do
    %{
      topology_available: map_size(chain_data.topology) > 0,
      inhabitants_count: length(chain_data.inhabitants),
      recent_activity_count: length(chain_data.recent_activity),
      threat_history_count: length(chain_data.threat_history),
      overall_quality: calculate_analysis_confidence(chain_data)
    }
  end

  @doc """
  Generate threat-specific recommendations based on threat type.
  """
  def threat_specific_recommendations(threat) do
    case threat.type do
      :high_threat_system -> [:avoid_system, :increase_intel]
      :activity_hotspot -> [:monitor_system, :avoid_if_possible]
      :threat_escalation -> [:prepare_evacuation, :increase_security]
      _ -> []
    end
  end
end
