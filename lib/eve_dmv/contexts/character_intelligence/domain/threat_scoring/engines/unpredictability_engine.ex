defmodule EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.Engines.UnpredictabilityEngine do
  @moduledoc """
  Unpredictability scoring engine for analyzing tactical variance and adaptation.

  Analyzes engagement patterns, ship selection variance, and tactical diversity
  to determine unpredictability threat level.
  """

  require Logger
  alias EveDmv.Contexts.CharacterIntelligence.Domain.ThreatScoring.SharedCalculations
  alias EveDmv.StaticData.SystemData

  # Ship type IDs for tactical roles
  @logistics_ids [11_978, 11_987, 11_985, 12_003]
  @ewar_ids [11_957, 11_958, 11_959, 11_961]
  @command_ids [22_470, 22_852, 17_918, 17_920]

  # Ship type ID ranges - note: dps range is more specific and should be checked first
  @dps_range 620..670
  @tackle_range 580..700
  @capital_range 19_720..19_740

  @doc """
  Calculate unpredictability score based on combat data.
  """
  def calculate_unpredictability_score(combat_data) when is_map(combat_data) do
    Logger.debug("Calculating unpredictability score")

    all_killmails = Map.get(combat_data, :killmails, [])

    if Enum.empty?(all_killmails) do
      %{
        raw_score: 0.5,
        normalized_score: 5.0,
        components: %{
          engagement_time_variety: 0.5,
          ship_selection_patterns: 0.5,
          tactical_variance: 0.5,
          location_diversity: 0.5
        },
        insights: ["Insufficient data for unpredictability analysis"]
      }
    else
      # Engagement time variety (when does character fight?)
      time_variety = analyze_engagement_time_variety(all_killmails)

      # Ship selection patterns (does character vary ship choices?)
      ship_patterns = analyze_ship_selection_patterns(combat_data)

      # Tactical variance (does character adapt tactics?)
      tactical_variance = analyze_tactical_variance(combat_data)

      # Location diversity (does character fight in different areas?)
      location_diversity = analyze_location_diversity(all_killmails)

      # Weighted unpredictability score
      raw_score =
        time_variety * 0.25 +
          ship_patterns.selection_variance * 0.30 +
          tactical_variance * 0.25 +
          location_diversity * 0.20

      %{
        raw_score: raw_score,
        normalized_score: normalize_to_10_scale(raw_score),
        components: %{
          engagement_time_variety: time_variety,
          ship_selection_patterns: ship_patterns.selection_variance,
          tactical_variance: tactical_variance,
          location_diversity: location_diversity
        },
        ship_selection_analysis: ship_patterns,
        insights:
          generate_unpredictability_insights(
            raw_score,
            time_variety,
            tactical_variance,
            location_diversity
          )
      }
    end
  end

  def calculate_unpredictability_score(_invalid_data) do
    Logger.warning(
      "Invalid combat_data provided to calculate_unpredictability_score - expected a map"
    )

    %{
      raw_score: 0.0,
      normalized_score: 0.0,
      components: %{
        engagement_time_variety: 0.0,
        ship_selection_patterns: 0.0,
        tactical_variance: 0.0,
        location_diversity: 0.0
      },
      insights: ["Invalid input data - unable to calculate unpredictability score"]
    }
  end

  @doc """
  Analyze engagement time variety patterns.
  """
  def analyze_engagement_time_variety(killmails) do
    Logger.debug("Analyzing engagement time variety for #{length(killmails)} killmails")

    if length(killmails) < 5 do
      # Not enough data for meaningful analysis
      0.5
    else
      # Extract timestamps and analyze temporal patterns
      timestamps = extract_killmail_timestamps(killmails)

      # Analyze time of day variety
      hour_variety = analyze_hour_of_day_variety(timestamps)

      # Analyze day of week variety
      day_variety = analyze_day_of_week_variety(timestamps)

      # Analyze engagement frequency patterns
      frequency_variance = analyze_engagement_frequency_variance(timestamps)

      # Combined time variety score
      hour_variety * 0.4 + day_variety * 0.3 + frequency_variance * 0.3
    end
  end

  @doc """
  Analyze ship selection patterns for unpredictability.
  """
  def analyze_ship_selection_patterns(combat_data) do
    Logger.debug("Analyzing ship selection patterns")

    all_killmails = Map.get(combat_data, :killmails, [])

    if Enum.empty?(all_killmails) do
      %{
        selection_variance: 0.5,
        adaptation_score: 0.5,
        predictability_index: 0.5,
        ship_diversity: 0.5
      }
    else
      # Extract ship usage patterns
      ship_usage = extract_ship_usage_patterns(all_killmails)

      # Calculate selection variance (how much variety in ship choices)
      selection_variance = calculate_ship_selection_variance(ship_usage)

      # Analyze adaptation patterns (changing ships based on situation)
      adaptation_score = analyze_ship_adaptation_patterns(all_killmails)

      # Calculate predictability index (reverse of unpredictability)
      predictability_index = calculate_ship_predictability_index(ship_usage)

      # Calculate ship diversity using Shannon entropy
      ship_diversity = calculate_ship_diversity_entropy(ship_usage)

      %{
        selection_variance: selection_variance,
        adaptation_score: adaptation_score,
        # Convert to unpredictability
        predictability_index: 1.0 - predictability_index,
        ship_diversity: ship_diversity,
        ship_usage_breakdown: ship_usage
      }
    end
  end

  @doc """
  Analyze tactical variance in combat behavior.
  """
  def analyze_tactical_variance(combat_data) do
    Logger.debug("Analyzing tactical variance")

    all_killmails = Map.get(combat_data, :killmails, [])
    attacker_killmails = Map.get(combat_data, :attacker_killmails, [])

    if Enum.empty?(all_killmails) do
      0.5
    else
      # Analyze target type variance (different victim ship classes)
      target_variance = analyze_target_type_variance(attacker_killmails)

      # Analyze engagement size variance (solo vs gang patterns)
      size_variance = analyze_engagement_size_variance(all_killmails)

      # Analyze damage pattern variance
      damage_variance =
        analyze_damage_pattern_variance(attacker_killmails, combat_data.character_id)

      # Analyze tactical role variance (different roles in combat)
      role_variance = analyze_tactical_role_variance(all_killmails)

      # Combined tactical variance score
      target_variance * 0.3 +
        size_variance * 0.25 +
        damage_variance * 0.25 +
        role_variance * 0.20
    end
  end

  @doc """
  Analyze location diversity in engagements.
  """
  def analyze_location_diversity(killmails) do
    Logger.debug("Analyzing location diversity for #{length(killmails)} killmails")

    if Enum.empty?(killmails) do
      0.5
    else
      # Extract system locations from killmails
      systems = extract_system_locations(killmails)

      # Calculate location diversity using Shannon entropy
      system_diversity = calculate_location_diversity_entropy(systems)

      # Analyze region diversity
      region_diversity = analyze_region_diversity(killmails)

      # Analyze security space variety (high-sec, low-sec, null-sec, wormhole)
      security_variety = analyze_security_space_variety(killmails)

      # Combined location diversity score
      system_diversity * 0.5 + region_diversity * 0.3 + security_variety * 0.2
    end
  end

  # Private helper functions

  defp extract_killmail_timestamps(killmails) do
    killmails
    |> Enum.map(& &1.killmail_time)
    |> Enum.filter(&(&1 != nil))
  end

  defp analyze_hour_of_day_variety(timestamps) do
    if Enum.empty?(timestamps) do
      0.5
    else
      # Extract hours from timestamps
      hours =
        timestamps
        |> Enum.map(&DateTime.to_time/1)
        |> Enum.map(& &1.hour)
        |> Enum.frequencies()

      # Calculate entropy of hour distribution
      total_engagements = Enum.sum(Map.values(hours))

      entropy =
        hours
        |> Enum.map(fn {_hour, count} ->
          probability = count / total_engagements
          -probability * :math.log(probability)
        end)
        |> Enum.sum()

      # Normalize entropy (max entropy for 24 hours is log(24))
      max_entropy = :math.log(24)
      if max_entropy > 0, do: entropy / max_entropy, else: 0.0
    end
  end

  defp analyze_day_of_week_variety(timestamps) do
    if Enum.empty?(timestamps) do
      0.5
    else
      # Extract day of week from timestamps
      days =
        timestamps
        |> Enum.map(&DateTime.to_date/1)
        |> Enum.map(&Date.day_of_week/1)
        |> Enum.frequencies()

      # Calculate entropy of day distribution
      total_engagements = Enum.sum(Map.values(days))

      entropy =
        days
        |> Enum.map(fn {_day, count} ->
          probability = count / total_engagements
          -probability * :math.log(probability)
        end)
        |> Enum.sum()

      # Normalize entropy (max entropy for 7 days is log(7))
      max_entropy = :math.log(7)
      if max_entropy > 0, do: entropy / max_entropy, else: 0.0
    end
  end

  defp analyze_engagement_frequency_variance(timestamps) do
    if length(timestamps) < 3 do
      0.5
    else
      # Calculate time gaps between engagements
      sorted_timestamps = Enum.sort(timestamps, &DateTime.compare/2)

      gaps =
        sorted_timestamps
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [t1, t2] -> DateTime.diff(t2, t1, :hour) end)
        |> Enum.filter(&(&1 > 0))

      if Enum.empty?(gaps) do
        0.5
      else
        # Calculate coefficient of variation for gaps
        mean_gap = Enum.sum(gaps) / length(gaps)

        variance =
          gaps
          |> Enum.map(&((&1 - mean_gap) * (&1 - mean_gap)))
          |> Enum.sum()
          |> Kernel./(length(gaps))

        std_dev = :math.sqrt(variance)
        coefficient_of_variation = if mean_gap > 0, do: std_dev / mean_gap, else: 0

        # Normalize to 0-1 scale (high variance = more unpredictable)
        min(1.0, coefficient_of_variation / 2.0)
      end
    end
  end

  defp extract_ship_usage_patterns(killmails) do
    # Extract ship types used by the character
    ship_types =
      killmails
      |> Enum.flat_map(fn km ->
        # Ship type when victim
        victim_ship = if km.victim_character_id, do: [km.victim_ship_type_id], else: []

        # Ship type when attacker
        attacker_ships =
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              attackers
              |> Enum.filter(&(&1["character_id"] != nil))
              |> Enum.map(& &1["ship_type_id"])
              |> Enum.filter(&(&1 != nil))

            _ ->
              []
          end

        victim_ship ++ attacker_ships
      end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.frequencies()

    ship_types
  end

  defp calculate_ship_selection_variance(ship_usage) do
    if map_size(ship_usage) <= 1 do
      # No variance with only one ship type
      0.0
    else
      total_usage = ship_usage |> Map.values() |> Enum.sum()

      # Calculate variance in ship usage frequencies
      mean_usage = total_usage / map_size(ship_usage)

      variance =
        ship_usage
        |> Map.values()
        |> Enum.map(&((&1 - mean_usage) * (&1 - mean_usage)))
        |> Enum.sum()
        |> Kernel./(map_size(ship_usage))

      # Normalize variance to 0-1 scale
      normalized_variance = min(1.0, variance / (mean_usage * mean_usage))
      normalized_variance
    end
  end

  defp analyze_ship_adaptation_patterns(killmails) do
    # Look for patterns where ship choice adapts to situation
    if length(killmails) < 5 do
      0.5
    else
      # Analyze if ship choices correlate with engagement context
      # This is a simplified version - would need more context data
      ship_usage = extract_ship_usage_patterns(killmails)
      unique_ships = map_size(ship_usage)

      # More ship types = better adaptation
      adaptation_score = min(1.0, unique_ships / 10)
      adaptation_score
    end
  end

  defp calculate_ship_predictability_index(ship_usage) do
    if map_size(ship_usage) == 0 do
      # Completely predictable (no data)
      1.0
    else
      total_usage = ship_usage |> Map.values() |> Enum.sum()
      max_usage = ship_usage |> Map.values() |> Enum.max()

      # High concentration on one ship = high predictability
      concentration_ratio = max_usage / total_usage
      concentration_ratio
    end
  end

  defp calculate_ship_diversity_entropy(ship_usage) do
    if map_size(ship_usage) == 0 do
      0.0
    else
      total_usage = ship_usage |> Map.values() |> Enum.sum()

      # Shannon entropy
      entropy =
        ship_usage
        |> Enum.map(fn {_ship, usage} ->
          probability = usage / total_usage
          -probability * :math.log(probability)
        end)
        |> Enum.sum()

      # Normalize by maximum possible entropy
      unique_ships = map_size(ship_usage)
      max_entropy = :math.log(unique_ships)
      if max_entropy > 0, do: entropy / max_entropy, else: 0.0
    end
  end

  defp analyze_target_type_variance(attacker_killmails) do
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      # Analyze variety in target ship types
      target_ships =
        attacker_killmails
        |> Enum.map(& &1.victim_ship_type_id)
        |> Enum.frequencies()

      # Calculate Shannon entropy of target selection
      total_kills = Enum.sum(Map.values(target_ships))

      entropy =
        target_ships
        |> Enum.map(fn {_ship, count} ->
          probability = count / total_kills
          -probability * :math.log(probability)
        end)
        |> Enum.sum()

      # Normalize entropy
      unique_targets = map_size(target_ships)
      max_entropy = if unique_targets > 1, do: :math.log(unique_targets), else: 1.0
      if max_entropy > 0, do: entropy / max_entropy, else: 0.0
    end
  end

  defp analyze_engagement_size_variance(killmails) do
    if Enum.empty?(killmails) do
      0.5
    else
      # Extract engagement sizes (number of attackers per killmail)
      engagement_sizes =
        killmails
        |> Enum.map(fn km ->
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              length(attackers)

            _ ->
              1
          end
        end)
        |> Enum.frequencies()

      # Calculate variance in engagement sizes
      if map_size(engagement_sizes) <= 1 do
        # No variance
        0.0
      else
        total_engagements = Enum.sum(Map.values(engagement_sizes))

        entropy =
          engagement_sizes
          |> Enum.map(fn {_size, count} ->
            probability = count / total_engagements
            -probability * :math.log(probability)
          end)
          |> Enum.sum()

        # Normalize entropy
        unique_sizes = map_size(engagement_sizes)
        max_entropy = :math.log(unique_sizes)
        if max_entropy > 0, do: entropy / max_entropy, else: 0.0
      end
    end
  end

  defp analyze_damage_pattern_variance(attacker_killmails, character_id) do
    if Enum.empty?(attacker_killmails) do
      0.5
    else
      # Analyze variance in damage contribution patterns
      damage_contributions =
        attacker_killmails
        |> Enum.map(&SharedCalculations.extract_damage_contribution(&1, character_id))
        |> Enum.filter(&(&1 > 0))

      if length(damage_contributions) < 2 do
        0.5
      else
        # Calculate coefficient of variation for damage contributions
        mean_damage = Enum.sum(damage_contributions) / length(damage_contributions)

        variance =
          damage_contributions
          |> Enum.map(&((&1 - mean_damage) * (&1 - mean_damage)))
          |> Enum.sum()
          |> Kernel./(length(damage_contributions))

        std_dev = :math.sqrt(variance)
        coefficient_of_variation = if mean_damage > 0, do: std_dev / mean_damage, else: 0

        # Normalize to 0-1 scale
        min(1.0, coefficient_of_variation * 2.0)
      end
    end
  end

  defp analyze_tactical_role_variance(killmails) do
    # Analyze variance in tactical roles played
    ship_roles =
      killmails
      |> Enum.flat_map(fn km ->
        # Extract ship types used by character
        victim_ships = if km.victim_character_id, do: [km.victim_ship_type_id], else: []

        attacker_ships =
          case km.raw_data do
            %{"attackers" => attackers} when is_list(attackers) ->
              attackers
              |> Enum.filter(&(&1["character_id"] != nil))
              |> Enum.map(& &1["ship_type_id"])
              |> Enum.filter(&(&1 != nil))

            _ ->
              []
          end

        victim_ships ++ attacker_ships
      end)
      |> Enum.filter(&(&1 != nil))
      |> Enum.map(&classify_tactical_role/1)
      |> Enum.frequencies()

    if map_size(ship_roles) <= 1 do
      # No role variance
      0.0
    else
      # Calculate entropy of role distribution
      total_usage = ship_roles |> Map.values() |> Enum.sum()

      entropy =
        ship_roles
        |> Enum.map(fn {_role, usage} ->
          probability = usage / total_usage
          -probability * :math.log(probability)
        end)
        |> Enum.sum()

      # Normalize entropy
      unique_roles = map_size(ship_roles)
      max_entropy = :math.log(unique_roles)
      if max_entropy > 0, do: entropy / max_entropy, else: 0.0
    end
  end

  defp classify_tactical_role(ship_type_id) do
    cond do
      ship_type_id in @logistics_ids -> :logistics
      ship_type_id in @ewar_ids -> :ewar
      ship_type_id in @command_ids -> :command
      # Check DPS range before tackle since they overlap
      ship_type_id in @dps_range -> :dps
      ship_type_id in @tackle_range -> :tackle
      ship_type_id in @capital_range -> :capital
      true -> :other
    end
  end

  defp extract_system_locations(killmails) do
    killmails
    |> Enum.map(& &1.solar_system_id)
    |> Enum.filter(&(&1 != nil))
    |> Enum.frequencies()
  end

  defp calculate_location_diversity_entropy(systems) do
    if map_size(systems) == 0 do
      0.0
    else
      total_engagements = systems |> Map.values() |> Enum.sum()

      # Shannon entropy for system distribution
      entropy =
        systems
        |> Enum.map(fn {_system, count} ->
          probability = count / total_engagements
          -probability * :math.log(probability)
        end)
        |> Enum.sum()

      # Normalize entropy
      unique_systems = map_size(systems)
      max_entropy = :math.log(unique_systems)
      if max_entropy > 0, do: entropy / max_entropy, else: 0.0
    end
  end

  defp analyze_region_diversity(killmails) do
    # This is simplified - would need EVE static data for actual regions
    # For now, estimate region diversity based on system ID ranges
    systems =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.filter(&(&1 != nil))
      |> Enum.uniq()

    if Enum.empty?(systems) do
      0.5
    else
      # Use centralized system data service for region diversity
      SystemData.calculate_region_diversity(systems)
    end
  end

  # Region estimation now handled by SystemData module

  defp analyze_security_space_variety(killmails) do
    # Analyze variety across security space types
    # This is simplified - would need EVE static data for actual security status
    systems =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.filter(&(&1 != nil))

    SystemData.calculate_security_diversity(systems)
  end

  # Security type estimation now handled by SystemData module

  defp generate_unpredictability_insights(
         raw_score,
         time_variety,
         tactical_variance,
         location_diversity
       ) do
    insights = []

    insights =
      if raw_score > 0.8 do
        ["Highly unpredictable opponent - difficult to anticipate" | insights]
      else
        insights
      end

    insights =
      if time_variety > 0.7 do
        ["Varies engagement times - no clear schedule pattern" | insights]
      else
        insights
      end

    insights =
      if tactical_variance > 0.7 do
        ["High tactical adaptability - changes approach frequently" | insights]
      else
        insights
      end

    insights =
      if location_diversity > 0.8 do
        ["Operates across diverse regions - wide operational range" | insights]
      else
        insights
      end

    insights =
      if raw_score < 0.3 do
        ["Predictable patterns - may be easier to anticipate" | insights]
      else
        insights
      end

    insights
  end

  defp normalize_to_10_scale(score) do
    SharedCalculations.normalize_to_10_scale(score)
  end
end
