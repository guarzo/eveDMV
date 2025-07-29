defmodule EveDmv.Shared.Strategic.TerritorialAnalyzer do
  @moduledoc """
  Analyzes territorial control patterns and contested areas.

  Responsible for:
  - Control zone identification
  - Contested area analysis
  - Expansion opportunity detection
  - Territory stability assessment
  """

  alias EveDmv.Shared.Strategic.Patterns.TerritorialPattern

  require Logger

  @territorial_control_threshold 0.6

  @doc """
  Analyzes territorial control patterns across systems.
  """
  def analyze_territorial_control(strategic_data, _options \\ []) do
    control_zones = TerritorialPattern.analyze_control_zones(strategic_data)
    contested_areas = identify_contested_areas(strategic_data, control_zones)
    expansion_opportunities = identify_expansion_opportunities(strategic_data, control_zones)

    %{
      control_zones: control_zones.control_zones,
      zone_stability: control_zones.zone_stability,
      dominant_entities: control_zones.dominant_entities,
      contested_areas: contested_areas,
      expansion_opportunities: expansion_opportunities,
      territorial_assessment: assess_territorial_situation(control_zones, contested_areas)
    }
  end

  @doc """
  Identifies areas of territorial contestation.
  """
  def identify_contested_areas(strategic_data, control_zones) do
    all_systems = extract_all_systems(strategic_data)
    controlled_systems = extract_controlled_systems(control_zones.control_zones)

    contested_systems =
      all_systems
      |> Enum.reject(&(&1 in controlled_systems))
      |> Enum.map(fn system ->
        analyze_contestation(system, strategic_data)
      end)
      |> Enum.reject(&is_nil/1)

    %{
      contested_count: length(contested_systems),
      contested_systems: contested_systems,
      contestation_intensity: calculate_overall_contestation(contested_systems),
      hot_zones: identify_hot_zones(contested_systems)
    }
  end

  @doc """
  Identifies territorial expansion opportunities.
  """
  def identify_expansion_opportunities(strategic_data, control_zones) do
    adjacent_systems = identify_adjacent_systems(control_zones.control_zones, strategic_data)
    weak_points = identify_weak_points(strategic_data)
    underutilized = identify_underutilized_systems(strategic_data)

    opportunities =
      (adjacent_systems ++ weak_points ++ underutilized)
      |> Enum.uniq_by(& &1.system_id)
      |> Enum.sort_by(& &1.opportunity_score, :desc)
      |> Enum.take(10)

    %{
      opportunity_count: length(opportunities),
      opportunities: opportunities,
      best_targets: Enum.take(opportunities, 3),
      expansion_direction: determine_expansion_direction(opportunities, control_zones)
    }
  end

  @doc """
  Assesses territorial stability over time.
  """
  def assess_territorial_stability(strategic_data, time_windows) do
    stability_metrics =
      time_windows
      |> Enum.map(fn window ->
        window_control = analyze_window_control(strategic_data, window)

        %{
          window: window,
          control_changes: window_control.changes,
          stability_score: window_control.stability,
          dominant_shift: window_control.dominant_shift
        }
      end)

    %{
      overall_stability: calculate_overall_stability(stability_metrics),
      control_changes: aggregate_control_changes(stability_metrics),
      stability_trend: determine_stability_trend(stability_metrics),
      volatile_systems: identify_volatile_systems(stability_metrics)
    }
  end

  # Private functions

  defp extract_all_systems(strategic_data) do
    case strategic_data.scope do
      :single_system -> [strategic_data.system_id]
      :multi_system -> Enum.map(strategic_data.killmail_data, & &1.system_id)
    end
  end

  defp extract_controlled_systems(control_zones) do
    control_zones
    |> Enum.filter(&(&1.control_level > @territorial_control_threshold))
    |> Enum.flat_map(& &1.systems)
  end

  defp analyze_contestation(system_id, strategic_data) do
    system_data = find_system_data(system_id, strategic_data)

    if system_data && system_data.kill_count > 0 do
      entities = extract_competing_entities(system_data.killmails)

      if map_size(entities) >= 2 do
        %{
          system_id: system_id,
          competing_entities: Map.keys(entities),
          entity_count: map_size(entities),
          conflict_intensity: calculate_conflict_intensity(system_data.killmails),
          balance_of_power: calculate_power_balance(entities),
          contestation_type: classify_contestation(entities)
        }
      else
        nil
      end
    else
      nil
    end
  end

  defp find_system_data(system_id, strategic_data) do
    case strategic_data.scope do
      :single_system ->
        if strategic_data.system_id == system_id do
          %{
            system_id: system_id,
            killmails: strategic_data.killmails,
            kill_count: length(strategic_data.killmails)
          }
        else
          nil
        end

      :multi_system ->
        Enum.find(strategic_data.killmail_data, &(&1.system_id == system_id))
    end
  end

  defp extract_competing_entities(killmails) do
    killmails
    |> Enum.flat_map(fn km ->
      attackers =
        km.attackers
        |> Enum.map(& &1.corporation_id)
        |> Enum.reject(&is_nil/1)

      victim = if km.victim.corporation_id, do: [km.victim.corporation_id], else: []

      attackers ++ victim
    end)
    |> Enum.frequencies()
    |> Enum.filter(fn {_, count} -> count >= 2 end)
    |> Map.new()
  end

  defp calculate_conflict_intensity(killmails) do
    if Enum.empty?(killmails) do
      0.0
    else
      # Factors: kill frequency, ship types involved, ISK destroyed
      time_span = calculate_time_span(killmails)
      kill_rate = if time_span > 0, do: length(killmails) / time_span, else: 0

      combat_ship_ratio = calculate_combat_ship_ratio(killmails)
      isk_intensity = calculate_isk_intensity(killmails)

      intensity = kill_rate * 0.4 + combat_ship_ratio * 0.3 + isk_intensity * 0.3
      Float.round(min(1.0, intensity), 3)
    end
  end

  defp calculate_time_span(killmails) do
    if length(killmails) < 2 do
      1
    else
      first = Enum.min_by(killmails, & &1.timestamp).timestamp
      last = Enum.max_by(killmails, & &1.timestamp).timestamp
      max(1, DateTime.diff(last, first, :hour))
    end
  end

  defp calculate_combat_ship_ratio(killmails) do
    combat_ships = [:battleship, :battlecruiser, :cruiser, :assault_frigate]

    combat_count =
      killmails
      |> Enum.count(fn km ->
        classify_ship_type(km.victim.ship_type_id) in combat_ships
      end)

    Float.round(combat_count / max(1, length(killmails)), 3)
  end

  defp calculate_isk_intensity(killmails) do
    total_isk =
      killmails
      |> Enum.map(&Map.get(&1, :zkb_total_value, 0))
      |> Enum.sum()

    # Normalize to 0-1 scale (1B ISK = 0.1)
    min(1.0, total_isk / 10_000_000_000)
  end

  defp calculate_power_balance(entities) do
    if map_size(entities) == 0 do
      %{balanced: true, dominant: nil, dominance_ratio: 0.0}
    else
      total = Enum.sum(Map.values(entities))
      {dominant, max_count} = Enum.max_by(entities, fn {_, count} -> count end)

      dominance_ratio = max_count / total

      %{
        balanced: dominance_ratio < 0.6,
        dominant: dominant,
        dominance_ratio: Float.round(dominance_ratio, 3)
      }
    end
  end

  defp classify_contestation(entities) do
    entity_count = map_size(entities)

    cond do
      entity_count == 2 -> :bilateral
      entity_count <= 4 -> :multilateral
      true -> :chaotic
    end
  end

  defp calculate_overall_contestation(contested_systems) do
    if Enum.empty?(contested_systems) do
      0.0
    else
      intensities = Enum.map(contested_systems, & &1.conflict_intensity)
      Float.round(Enum.sum(intensities) / length(intensities), 3)
    end
  end

  defp identify_hot_zones(contested_systems) do
    contested_systems
    |> Enum.filter(&(&1.conflict_intensity > 0.7))
    |> Enum.sort_by(& &1.conflict_intensity, :desc)
    |> Enum.take(3)
    |> Enum.map(fn zone ->
      %{
        system_id: zone.system_id,
        intensity: zone.conflict_intensity,
        competitors: zone.competing_entities,
        classification: :high_conflict
      }
    end)
  end

  defp identify_adjacent_systems(control_zones, strategic_data) do
    # Simplified - in production would use actual gate connections
    controlled = control_zones |> Enum.flat_map(& &1.systems)
    all_systems = extract_all_systems(strategic_data)

    all_systems
    |> Enum.reject(&(&1 in controlled))
    |> Enum.map(fn system ->
      %{
        system_id: system,
        opportunity_type: :adjacent_expansion,
        opportunity_score: calculate_expansion_score(system, strategic_data),
        risk_level: :low
      }
    end)
  end

  defp identify_weak_points(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        strategic_data.killmail_data
        |> Enum.filter(&(&1.kill_count > 0))
        |> Enum.map(fn data ->
          weakness_score = analyze_system_weakness(data)

          if weakness_score > 0.5 do
            %{
              system_id: data.system_id,
              opportunity_type: :weak_control,
              opportunity_score: weakness_score,
              risk_level: :medium
            }
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)

      :single_system ->
        []
    end
  end

  defp analyze_system_weakness(system_data) do
    # Low activity + no dominant controller = weak
    entities = extract_competing_entities(system_data.killmails)

    if map_size(entities) == 0 do
      # Uncontrolled system
      1.0
    else
      power_balance = calculate_power_balance(entities)
      activity_level = min(1.0, system_data.kill_count / 50)

      weakness = (1.0 - power_balance.dominance_ratio) * 0.6 + (1.0 - activity_level) * 0.4
      Float.round(weakness, 3)
    end
  end

  defp identify_underutilized_systems(strategic_data) do
    case strategic_data.scope do
      :multi_system ->
        avg_activity = calculate_average_activity(strategic_data)

        strategic_data.killmail_data
        |> Enum.filter(&(&1.kill_count < avg_activity * 0.3))
        |> Enum.map(fn data ->
          %{
            system_id: data.system_id,
            opportunity_type: :underutilized,
            opportunity_score: 0.5,
            risk_level: :low
          }
        end)

      :single_system ->
        []
    end
  end

  defp calculate_average_activity(strategic_data) do
    total_kills =
      strategic_data.killmail_data
      |> Enum.map(& &1.kill_count)
      |> Enum.sum()

    system_count = length(strategic_data.killmail_data)

    if system_count > 0 do
      total_kills / system_count
    else
      0.0
    end
  end

  defp calculate_expansion_score(system_id, strategic_data) do
    system_data = find_system_data(system_id, strategic_data)

    if system_data do
      activity_factor = min(1.0, system_data.kill_count / 20) * 0.3
      weakness_factor = analyze_system_weakness(system_data) * 0.7

      Float.round(activity_factor + weakness_factor, 3)
    else
      # Default score for unknown systems
      0.5
    end
  end

  defp determine_expansion_direction(opportunities, _control_zones) do
    if Enum.empty?(opportunities) do
      :no_clear_direction
    else
      # Group opportunities by type
      by_type = Enum.group_by(opportunities, & &1.opportunity_type)

      cond do
        length(Map.get(by_type, :adjacent_expansion, [])) >= 3 ->
          :outward_expansion

        length(Map.get(by_type, :weak_control, [])) >= 3 ->
          :consolidation

        length(Map.get(by_type, :underutilized, [])) >= 3 ->
          :infill

        true ->
          :mixed_opportunities
      end
    end
  end

  defp assess_territorial_situation(control_zones, contested_areas) do
    control_ratio = calculate_control_ratio(control_zones)
    contestation_level = contested_areas.contestation_intensity

    situation =
      cond do
        control_ratio > 0.7 && contestation_level < 0.3 ->
          :dominant_control

        control_ratio > 0.5 && contestation_level < 0.5 ->
          :stable_control

        control_ratio > 0.3 && contestation_level > 0.5 ->
          :contested_territory

        contestation_level > 0.7 ->
          :highly_contested

        true ->
          :fragmented_control
      end

    %{
      situation: situation,
      control_ratio: control_ratio,
      contestation_level: contestation_level,
      recommendation: generate_territorial_recommendation(situation)
    }
  end

  defp calculate_control_ratio(control_zones) do
    if Enum.empty?(control_zones.control_zones) do
      0.0
    else
      controlled =
        Enum.count(
          control_zones.control_zones,
          &(&1.control_level > @territorial_control_threshold)
        )

      Float.round(controlled / length(control_zones.control_zones), 3)
    end
  end

  defp generate_territorial_recommendation(situation) do
    case situation do
      :dominant_control ->
        "Maintain current positions and consider selective expansion"

      :stable_control ->
        "Consolidate control in existing territories"

      :contested_territory ->
        "Focus on securing contested areas"

      :highly_contested ->
        "Defensive posture recommended, protect key systems"

      :fragmented_control ->
        "Establish core territories before expansion"
    end
  end

  defp analyze_window_control(strategic_data, {start_time, end_time}) do
    window_kills = filter_kills_by_window(strategic_data, start_time, end_time)

    control_data = calculate_window_control(window_kills)
    # Simplified - would track across windows
    previous_control = %{}

    changes = detect_control_changes(control_data, previous_control)

    %{
      changes: changes,
      stability: calculate_window_stability(changes),
      dominant_shift: identify_dominant_shift(changes)
    }
  end

  defp filter_kills_by_window(strategic_data, start_time, end_time) do
    case strategic_data.scope do
      :single_system ->
        strategic_data.killmails
        |> Enum.filter(fn km ->
          DateTime.compare(km.timestamp, start_time) != :lt &&
            DateTime.compare(km.timestamp, end_time) == :lt
        end)

      :multi_system ->
        strategic_data.killmail_data
        |> Enum.map(fn data ->
          filtered_kills =
            data.killmails
            |> Enum.filter(fn km ->
              DateTime.compare(km.timestamp, start_time) != :lt &&
                DateTime.compare(km.timestamp, end_time) == :lt
            end)

          %{system_id: data.system_id, killmails: filtered_kills}
        end)
    end
  end

  defp calculate_window_control(window_data)
       when is_list(window_data) and window_data != [] do
    # Handle list of killmails (single system)
    if is_map(List.first(window_data)) && Map.has_key?(List.first(window_data), :attackers) do
      entities = extract_competing_entities(window_data)

      if map_size(entities) > 0 do
        {dominant, _} = Enum.max_by(entities, fn {_, count} -> count end)
        %{dominant_controller: dominant}
      else
        %{dominant_controller: nil}
      end
    else
      # Handle multi-system data
      window_data
      |> Enum.map(fn system_data ->
        entities = extract_competing_entities(system_data.killmails)

        dominant = find_dominant_entity(entities)

        {system_data.system_id, dominant}
      end)
      |> Map.new()
    end
  end

  defp calculate_window_control(_), do: %{}

  defp detect_control_changes(current_control, previous_control) when is_map(current_control) do
    Map.keys(current_control)
    |> Enum.map(fn key ->
      current = Map.get(current_control, key)
      previous = Map.get(previous_control, key)

      if current != previous do
        %{
          system: key,
          from: previous,
          to: current,
          change_type: classify_control_change(previous, current)
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp detect_control_changes(_, _), do: []

  defp classify_control_change(nil, _), do: :control_established
  defp classify_control_change(_, nil), do: :control_lost
  defp classify_control_change(_, _), do: :control_shifted

  defp calculate_window_stability(changes) do
    # Fewer changes = higher stability
    change_factor = length(changes)

    cond do
      change_factor == 0 -> 1.0
      change_factor <= 2 -> 0.7
      change_factor <= 5 -> 0.4
      true -> 0.1
    end
  end

  defp identify_dominant_shift(changes) do
    if Enum.empty?(changes) do
      nil
    else
      # Look for entity gaining most control
      gains =
        changes
        |> Enum.filter(&(&1.change_type in [:control_established, :control_shifted]))
        |> Enum.group_by(& &1.to)
        |> Enum.map(fn {entity, changes} -> {entity, length(changes)} end)
        |> Enum.max_by(fn {_, count} -> count end, fn -> {nil, 0} end)

      case gains do
        {nil, _} -> nil
        {entity, count} -> %{entity: entity, systems_gained: count}
      end
    end
  end

  defp calculate_overall_stability(stability_metrics) do
    if Enum.empty?(stability_metrics) do
      1.0
    else
      scores = Enum.map(stability_metrics, & &1.stability_score)
      Float.round(Enum.sum(scores) / length(scores), 3)
    end
  end

  defp aggregate_control_changes(stability_metrics) do
    all_changes =
      stability_metrics
      |> Enum.flat_map(& &1.control_changes)

    %{
      total_changes: length(all_changes),
      changes_by_type: Enum.frequencies_by(all_changes, & &1.change_type),
      most_volatile: identify_most_changed_system(all_changes)
    }
  end

  defp identify_most_changed_system(changes) do
    if Enum.empty?(changes) do
      nil
    else
      changes
      |> Enum.frequencies_by(& &1.system)
      |> Enum.max_by(fn {_, count} -> count end)
      |> elem(0)
    end
  end

  defp determine_stability_trend(stability_metrics) do
    if length(stability_metrics) < 2 do
      :insufficient_data
    else
      scores = Enum.map(stability_metrics, & &1.stability_score)

      first_half = Enum.take(scores, div(length(scores), 2))
      second_half = Enum.drop(scores, div(length(scores), 2))

      first_avg = Enum.sum(first_half) / length(first_half)
      second_avg = Enum.sum(second_half) / length(second_half)

      cond do
        second_avg > first_avg * 1.1 -> :stabilizing
        second_avg < first_avg * 0.9 -> :destabilizing
        true -> :stable
      end
    end
  end

  defp identify_volatile_systems(stability_metrics) do
    stability_metrics
    |> Enum.flat_map(& &1.control_changes)
    |> Enum.group_by(& &1.system)
    |> Enum.map(fn {system, changes} ->
      %{
        system_id: system,
        change_count: length(changes),
        volatility: classify_volatility(length(changes))
      }
    end)
    |> Enum.filter(&(&1.volatility in [:high, :extreme]))
    |> Enum.sort_by(& &1.change_count, :desc)
  end

  defp classify_volatility(change_count) do
    cond do
      change_count >= 5 -> :extreme
      change_count >= 3 -> :high
      change_count >= 2 -> :moderate
      change_count >= 1 -> :low
      true -> :stable
    end
  end

  defp classify_ship_type(ship_type_id) do
    # Use actual ship classification from static data
    case EveDmv.StaticData.ShipTypes.classify_ship_type(ship_type_id) do
      {:ok, ship_class} -> ship_class
      {:error, _} -> :other
    end
  end

  defp find_dominant_entity(entities) do
    if map_size(entities) > 0 do
      {dom, _} = Enum.max_by(entities, fn {_, count} -> count end)
      dom
    else
      nil
    end
  end
end
