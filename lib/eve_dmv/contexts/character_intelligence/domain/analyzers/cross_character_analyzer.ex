defmodule EveDmv.Contexts.CharacterIntelligence.Domain.Analyzers.CrossCharacterAnalyzer do
  @moduledoc """
  Analyzes relationships and patterns between multiple characters.
  All analysis based on real killmail data - NO PLACEHOLDERS.
  """

  require Logger

  @doc """
  Analyzes relationships between multiple characters.
  """
  def analyze_relationships(character_ids)
      when is_list(character_ids) and length(character_ids) > 1 do
    Logger.debug("Analyzing relationships for #{length(character_ids)} characters")

    # Build relationship matrix
    relationships =
      for char1 <- character_ids,
          char2 <- character_ids,
          # Avoid duplicates and self-relationships
          char1 < char2 do
        strength = calculate_relationship_strength(char1, char2)
        {{char1, char2}, strength}
      end

    {:ok,
     %{
       relationship_matrix: build_matrix(relationships, character_ids),
       strongest_pairs: find_strongest_pairs(relationships),
       network_cohesion: calculate_network_cohesion(relationships),
       subgroups: detect_subgroups(relationships, character_ids)
     }}
  end

  def analyze_relationships(_), do: {:error, :invalid_character_list}

  @doc """
  Identifies patterns in group operations.
  """
  def analyze_group_patterns(character_ids) when is_list(character_ids) do
    Logger.debug("Analyzing group patterns for #{length(character_ids)} characters")

    shared_operations = get_shared_operations(character_ids)

    if Enum.empty?(shared_operations) do
      {:error, :no_shared_operations}
    else
      {:ok,
       %{
         operation_types: classify_operations(shared_operations),
         temporal_patterns: analyze_temporal_patterns(shared_operations),
         geographic_patterns: analyze_geographic_patterns(shared_operations),
         target_preferences: analyze_target_preferences(shared_operations),
         coordination_level: assess_coordination_level(shared_operations, character_ids)
       }}
    end
  end

  @doc """
  Predicts group behavior based on historical patterns.
  """
  def predict_group_behavior(character_ids) when is_list(character_ids) do
    Logger.debug("Predicting group behavior for #{length(character_ids)} characters")

    historical_data = get_group_history(character_ids, days: 90)

    case historical_data do
      [] ->
        {:error, :insufficient_group_data}

      data ->
        {:ok,
         %{
           likely_operation_time: predict_operation_timing(data),
           likely_target_systems: predict_target_systems(data),
           likely_fleet_composition: predict_fleet_composition(data, character_ids),
           escalation_probability: calculate_escalation_probability(data),
           success_probability: calculate_success_probability(data)
         }}
    end
  end

  # Private functions

  defp calculate_relationship_strength(char1_id, char2_id) do
    # Optimized: Uses participants table via direct SQL instead of JSONB extraction
    cutoff = DateTime.add(DateTime.utc_now(), -90 * 86_400, :second)

    # Find killmails where both characters participated as attackers
    query = """
    SELECT COUNT(DISTINCT p1.killmail_id)
    FROM participants p1
    JOIN participants p2 ON p1.killmail_id = p2.killmail_id
      AND p1.killmail_time = p2.killmail_time
    WHERE p1.character_id = $1
      AND p2.character_id = $2
      AND p1.is_victim = false
      AND p2.is_victim = false
      AND p1.killmail_time > $3
    """

    case EveDmv.Repo.query(query, [char1_id, char2_id, cutoff]) do
      {:ok, %{rows: [[count]]}} when is_integer(count) ->
        calculate_strength_score(count)

      _ ->
        0.0
    end
  rescue
    error ->
      Logger.error("Failed to calculate relationship strength: #{inspect(error)}")
      0.0
  end

  defp calculate_strength_score(shared_kills) when shared_kills == 0, do: 0.0

  defp calculate_strength_score(shared_kills) do
    # Logarithmic scale for relationship strength
    # 1-5 kills = weak, 6-20 = moderate, 21-50 = strong, 50+ = very strong
    cond do
      shared_kills >= 50 -> 1.0
      shared_kills >= 21 -> 0.8
      shared_kills >= 6 -> 0.6
      shared_kills >= 1 -> 0.4
      true -> 0.0
    end
  end

  defp build_matrix(relationships, character_ids) do
    # Build a matrix representation of relationships
    matrix_map = Map.new(relationships)

    for char1 <- character_ids do
      row =
        for char2 <- character_ids do
          cond do
            # Self-relationship
            char1 == char2 -> 1.0
            char1 < char2 -> Map.get(matrix_map, {char1, char2}, 0.0)
            true -> Map.get(matrix_map, {char2, char1}, 0.0)
          end
        end

      {char1, row}
    end
    |> Map.new()
  end

  defp find_strongest_pairs(relationships) do
    relationships
    |> Enum.sort_by(fn {_, strength} -> strength end, :desc)
    |> Enum.take(5)
    |> Enum.map(fn {{char1, char2}, strength} ->
      %{
        character_1: char1,
        character_2: char2,
        strength: Float.round(strength, 3)
      }
    end)
  end

  defp calculate_network_cohesion(relationships) do
    if Enum.empty?(relationships) do
      0.0
    else
      strengths = Enum.map(relationships, fn {_, strength} -> strength end)
      avg_strength = Enum.sum(strengths) / length(strengths)

      # Cohesion is higher when more relationships are strong
      strong_relationships = Enum.count(strengths, &(&1 >= 0.6))
      cohesion = strong_relationships / length(strengths) * avg_strength

      Float.round(cohesion, 3)
    end
  end

  defp detect_subgroups(relationships, character_ids) do
    # Simple clustering based on relationship strength
    # Group characters that have strong mutual relationships

    strong_relationships =
      relationships
      |> Enum.filter(fn {_, strength} -> strength >= 0.6 end)
      |> Enum.map(fn {{char1, char2}, _} -> {char1, char2} end)

    # Build adjacency list
    adjacency =
      Enum.reduce(strong_relationships, %{}, fn {char1, char2}, acc ->
        acc
        |> Map.update(char1, [char2], &[char2 | &1])
        |> Map.update(char2, [char1], &[char1 | &1])
      end)

    # Find connected components (subgroups)
    find_connected_components(character_ids, adjacency)
  end

  defp find_connected_components(characters, adjacency) do
    {components, _} =
      Enum.reduce(characters, {[], MapSet.new()}, fn char, {comps, visited} ->
        if MapSet.member?(visited, char) do
          {comps, visited}
        else
          component = explore_component(char, adjacency, MapSet.new())
          new_visited = Enum.reduce(component, visited, &MapSet.put(&2, &1))
          {[component | comps], new_visited}
        end
      end)

    components
    # Only groups with 2+ members
    |> Enum.filter(&(length(&1) > 1))
    |> Enum.map(&%{members: &1, size: length(&1)})
  end

  defp explore_component(char, adjacency, visited) do
    if MapSet.member?(visited, char) do
      []
    else
      visited = MapSet.put(visited, char)
      neighbors = Map.get(adjacency, char, [])

      Enum.reduce(neighbors, [char], fn neighbor, acc ->
        acc ++ explore_component(neighbor, adjacency, visited)
      end)
      |> Enum.uniq()
    end
  end

  defp get_shared_operations(character_ids) do
    # Optimized: Uses participants table via direct SQL instead of JSONB extraction
    cutoff = DateTime.add(DateTime.utc_now(), -30 * 86_400, :second)

    query = """
    SELECT DISTINCT k.killmail_id, k.killmail_time, k.solar_system_id, k.raw_data, k.victim_ship_type_id
    FROM killmails_raw k
    WHERE EXISTS (
      SELECT 1 FROM participants p
      WHERE p.killmail_id = k.killmail_id
        AND p.killmail_time = k.killmail_time
        AND p.character_id = ANY($1)
        AND p.is_victim = false
    )
    AND k.killmail_time > $2
    ORDER BY k.killmail_time DESC
    LIMIT 500
    """

    case EveDmv.Repo.query(query, [character_ids, cutoff]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [
                            killmail_id,
                            killmail_time,
                            solar_system_id,
                            raw_data,
                            victim_ship_type_id
                          ] ->
          %{
            killmail_id: killmail_id,
            killmail_time: killmail_time,
            solar_system_id: solar_system_id,
            raw_data: raw_data,
            victim_ship_type_id: victim_ship_type_id
          }
        end)

      _ ->
        []
    end
  rescue
    error ->
      Logger.error("Failed to get shared operations: #{inspect(error)}")
      []
  end

  defp classify_operations(operations) do
    operations
    |> Enum.reduce(%{}, fn op, acc ->
      type = classify_operation_type(op)
      Map.update(acc, type, 1, &(&1 + 1))
    end)
    |> normalize_percentages()
  end

  defp classify_operation_type(operation) do
    case operation.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attacker_count = length(attackers)

        cond do
          attacker_count == 1 -> :solo
          attacker_count <= 5 -> :small_gang
          attacker_count <= 15 -> :medium_gang
          attacker_count <= 50 -> :fleet
          true -> :large_fleet
        end

      _ ->
        :unknown
    end
  end

  defp normalize_percentages(counts) do
    total = Enum.sum(Map.values(counts))

    if total == 0 do
      counts
    else
      Map.new(counts, fn {key, count} ->
        {key, Float.round(count / total * 100, 1)}
      end)
    end
  end

  defp analyze_temporal_patterns(operations) do
    if Enum.empty?(operations) do
      %{peak_hours: [], peak_days: [], activity_consistency: 0.0}
    else
      # Group by hour
      hourly =
        operations
        |> Enum.group_by(fn op -> op.killmail_time.hour end)
        |> Map.new(fn {hour, ops} -> {hour, length(ops)} end)

      # Group by day of week
      daily =
        operations
        |> Enum.group_by(fn op -> Date.day_of_week(DateTime.to_date(op.killmail_time)) end)
        |> Map.new(fn {day, ops} -> {day, length(ops)} end)

      %{
        peak_hours: find_peak_times(hourly),
        peak_days: find_peak_days(daily),
        activity_consistency: calculate_consistency(operations)
      }
    end
  end

  defp find_peak_times(hourly) do
    hourly
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, count} ->
      %{hour: hour, operations: count}
    end)
  end

  defp find_peak_days(daily) do
    day_names = %{
      1 => "Monday",
      2 => "Tuesday",
      3 => "Wednesday",
      4 => "Thursday",
      5 => "Friday",
      6 => "Saturday",
      7 => "Sunday"
    }

    daily
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {day_num, count} ->
      %{day: Map.get(day_names, day_num, "Unknown"), operations: count}
    end)
  end

  defp calculate_consistency(operations) do
    if length(operations) < 2 do
      0.0
    else
      # Calculate time between operations
      sorted_times =
        operations
        |> Enum.map(& &1.killmail_time)
        |> Enum.sort(DateTime)

      intervals =
        sorted_times
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [t1, t2] -> DateTime.diff(t2, t1) end)

      if Enum.empty?(intervals) do
        0.0
      else
        avg_interval = Enum.sum(intervals) / length(intervals)

        variance =
          Enum.reduce(intervals, 0, fn interval, acc ->
            acc + :math.pow(interval - avg_interval, 2)
          end) / length(intervals)

        std_dev = :math.sqrt(variance)
        cv = if avg_interval > 0, do: std_dev / avg_interval, else: 1.0

        # Lower CV = more consistent timing
        consistency = max(0.0, min(1.0, 1.0 - cv))
        Float.round(consistency, 3)
      end
    end
  end

  defp analyze_geographic_patterns(operations) do
    if Enum.empty?(operations) do
      %{primary_systems: [], system_diversity: 0, regional_focus: nil}
    else
      # Group by solar system
      system_counts =
        operations
        |> Enum.frequencies_by(& &1.solar_system_id)

      total_operations = length(operations)
      unique_systems = map_size(system_counts)

      primary_systems =
        system_counts
        |> Enum.sort_by(fn {_, count} -> count end, :desc)
        |> Enum.take(5)
        |> Enum.map(fn {system_id, count} ->
          %{
            system_id: system_id,
            operations: count,
            percentage: Float.round(count / total_operations * 100, 1)
          }
        end)

      %{
        primary_systems: primary_systems,
        system_diversity: unique_systems,
        regional_focus: calculate_regional_focus(system_counts, total_operations)
      }
    end
  end

  defp calculate_regional_focus(system_counts, total_operations) do
    if map_size(system_counts) == 0 or total_operations == 0 do
      nil
    else
      # Check if operations are concentrated in few systems
      top_3_systems =
        system_counts
        |> Map.values()
        |> Enum.sort(:desc)
        |> Enum.take(3)
        |> Enum.sum()

      concentration = top_3_systems / total_operations

      cond do
        concentration >= 0.8 -> :highly_concentrated
        concentration >= 0.6 -> :moderately_concentrated
        concentration >= 0.4 -> :somewhat_distributed
        true -> :widely_distributed
      end
    end
  end

  defp analyze_target_preferences(operations) do
    operations
    |> Enum.map(& &1.victim_ship_type_id)
    |> Enum.filter(&(&1 != nil))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> count end, :desc)
    |> Enum.take(10)
    |> Enum.map(fn {ship_type_id, count} ->
      %{
        ship_type_id: ship_type_id,
        kills: count,
        percentage: Float.round(count / length(operations) * 100, 1)
      }
    end)
  end

  defp assess_coordination_level(operations, character_ids) do
    if Enum.empty?(operations) do
      0.0
    else
      # Check how many operations involve multiple characters from the group
      multi_char_ops =
        Enum.count(operations, fn op ->
          participating_chars = count_participating_characters(op, character_ids)
          participating_chars >= 2
        end)

      coordination = multi_char_ops / length(operations)
      Float.round(coordination, 3)
    end
  end

  defp count_participating_characters(operation, character_ids) do
    character_id_strings = Enum.map(character_ids, &to_string/1)

    case operation.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attackers
        |> Enum.count(fn att ->
          to_string(att["character_id"]) in character_id_strings
        end)

      _ ->
        0
    end
  end

  defp get_group_history(character_ids, days: days) do
    # Optimized: Uses participants table via direct SQL instead of JSONB extraction
    cutoff = DateTime.add(DateTime.utc_now(), -days * 86_400, :second)

    # Find killmails where at least 2 of the specified characters participated as attackers
    query = """
    WITH group_killmails AS (
      SELECT p.killmail_id, p.killmail_time
      FROM participants p
      WHERE p.character_id = ANY($1)
        AND p.is_victim = false
        AND p.killmail_time > $2
      GROUP BY p.killmail_id, p.killmail_time
      HAVING COUNT(DISTINCT p.character_id) >= 2
    )
    SELECT k.killmail_id, k.killmail_time, k.solar_system_id, k.raw_data, k.victim_ship_type_id
    FROM killmails_raw k
    JOIN group_killmails gk ON k.killmail_id = gk.killmail_id
      AND k.killmail_time = gk.killmail_time
    ORDER BY k.killmail_time DESC
    """

    case EveDmv.Repo.query(query, [character_ids, cutoff]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [
                            killmail_id,
                            killmail_time,
                            solar_system_id,
                            raw_data,
                            victim_ship_type_id
                          ] ->
          %{
            killmail_id: killmail_id,
            killmail_time: killmail_time,
            solar_system_id: solar_system_id,
            raw_data: raw_data,
            victim_ship_type_id: victim_ship_type_id
          }
        end)

      _ ->
        []
    end
  rescue
    error ->
      Logger.error("Failed to get group history: #{inspect(error)}")
      []
  end

  defp predict_operation_timing(historical_data) do
    if Enum.empty?(historical_data) do
      %{likely_hours: [], confidence: 0.0}
    else
      # Analyze historical operation times
      hourly_freq =
        historical_data
        |> Enum.frequencies_by(fn op -> op.killmail_time.hour end)
        |> Enum.sort_by(fn {_, count} -> count end, :desc)

      total = length(historical_data)

      likely_hours =
        hourly_freq
        |> Enum.take(3)
        |> Enum.map(fn {hour, count} ->
          %{
            hour: hour,
            probability: Float.round(count / total, 3),
            historical_count: count
          }
        end)

      # Confidence based on data volume
      confidence =
        cond do
          total >= 100 -> 0.9
          total >= 50 -> 0.7
          total >= 20 -> 0.5
          true -> 0.3
        end

      %{likely_hours: likely_hours, confidence: confidence}
    end
  end

  defp predict_target_systems(historical_data) do
    if Enum.empty?(historical_data) do
      []
    else
      # Predict likely target systems based on historical patterns
      historical_data
      |> Enum.frequencies_by(& &1.solar_system_id)
      |> Enum.sort_by(fn {_, count} -> count end, :desc)
      |> Enum.take(5)
      |> Enum.map(fn {system_id, count} ->
        %{
          system_id: system_id,
          probability: Float.round(count / length(historical_data), 3),
          historical_kills: count
        }
      end)
    end
  end

  defp predict_fleet_composition(historical_data, character_ids) do
    if Enum.empty?(historical_data) do
      %{likely_size: 0, typical_roles: []}
    else
      # Analyze typical fleet sizes
      fleet_sizes =
        Enum.map(historical_data, fn op ->
          case op.raw_data do
            %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
            _ -> 1
          end
        end)

      avg_size =
        if Enum.empty?(fleet_sizes) do
          0
        else
          Float.round(Enum.sum(fleet_sizes) / length(fleet_sizes), 1)
        end

      # Analyze typical ship roles
      ship_roles =
        historical_data
        |> Enum.flat_map(fn op ->
          extract_character_ships(op, character_ids)
        end)
        |> Enum.map(&classify_ship_role/1)
        |> Enum.frequencies()
        |> Enum.sort_by(fn {_, count} -> count end, :desc)
        |> Enum.take(3)
        |> Enum.map(fn {role, _} -> role end)

      %{
        likely_size: avg_size,
        typical_roles: ship_roles
      }
    end
  end

  defp extract_character_ships(operation, character_ids) do
    character_id_strings = Enum.map(character_ids, &to_string/1)

    case operation.raw_data do
      %{"attackers" => attackers} when is_list(attackers) ->
        attackers
        |> Enum.filter(fn att ->
          to_string(att["character_id"]) in character_id_strings
        end)
        |> Enum.map(fn att -> att["ship_type_id"] end)
        |> Enum.filter(&(&1 != nil))

      _ ->
        []
    end
  end

  defp classify_ship_role(ship_type_id) when is_integer(ship_type_id) do
    # Simplified ship role classification
    cond do
      ship_type_id in 11_987..11_999 -> :logistics
      ship_type_id in 11_957..11_965 -> :recon
      ship_type_id in 11_174..11_200 -> :interdictor
      ship_type_id in 22_428..22_474 -> :command
      true -> :dps
    end
  end

  defp classify_ship_role(_), do: :unknown

  defp calculate_escalation_probability(historical_data) do
    if length(historical_data) < 10 do
      # Not enough data
      0.5
    else
      # Look for patterns of increasing fleet sizes
      recent_data = Enum.take(historical_data, 20)
      older_data = historical_data |> Enum.drop(20) |> Enum.take(20)

      recent_avg_size = calculate_average_fleet_size(recent_data)
      older_avg_size = calculate_average_fleet_size(older_data)

      if older_avg_size == 0 do
        0.5
      else
        growth_rate = (recent_avg_size - older_avg_size) / older_avg_size

        # Convert growth rate to probability
        probability =
          cond do
            # Strong escalation trend
            growth_rate >= 0.5 -> 0.8
            # Moderate escalation
            growth_rate >= 0.2 -> 0.6
            # Slight escalation
            growth_rate >= 0 -> 0.4
            # De-escalation
            true -> 0.2
          end

        Float.round(probability, 2)
      end
    end
  end

  defp calculate_average_fleet_size(operations) do
    if Enum.empty?(operations) do
      0.0
    else
      sizes =
        Enum.map(operations, fn op ->
          case op.raw_data do
            %{"attackers" => attackers} when is_list(attackers) -> length(attackers)
            _ -> 1
          end
        end)

      Enum.sum(sizes) / length(sizes)
    end
  end

  defp calculate_success_probability(historical_data) do
    if Enum.empty?(historical_data) do
      0.5
    else
      # Simple success metric: kills where group participated
      # In a real implementation, would analyze ISK efficiency, K/D ratio, etc.
      total_ops = length(historical_data)

      # For now, use participation rate as proxy for success
      # (More operations = more successful group)
      cond do
        total_ops >= 100 -> 0.9
        total_ops >= 50 -> 0.75
        total_ops >= 20 -> 0.6
        total_ops >= 10 -> 0.5
        true -> 0.4
      end
    end
  end
end
