defmodule EveDmv.Contexts.SystemAnalysis.Domain.EscalationDetector do
  @moduledoc """
  Detects and predicts escalation patterns in system activity.
  Identifies when small conflicts grow into larger engagements.
  """

  import Ash.Query

  alias EveDmv.Killmails.KillmailRaw

  @doc """
  Detects escalation patterns in a system or region
  """
  def detect_escalations(scope, timeframe_opts \\ []) do
    timeframe = build_timeframe(timeframe_opts)

    with {:ok, killmails} <- get_scoped_killmails(scope, timeframe) do
      # Group killmails into potential escalation windows
      windows = identify_escalation_windows(killmails)

      # Analyze each window for escalation patterns
      escalations =
        Enum.map(windows, fn window ->
          analyze_escalation_window(window)
        end)
        |> Enum.filter(& &1.is_escalation)

      {:ok,
       %{
         scope: scope,
         timeframe: timeframe,
         escalations_detected: length(escalations),
         escalation_events: escalations,
         risk_assessment: assess_current_risk(killmails),
         predictions: predict_future_escalations(escalations, killmails)
       }}
    end
  end

  @doc """
  Real-time escalation monitoring
  """
  def monitor_escalation(system_id, window_minutes \\ 30) do
    cutoff = DateTime.add(DateTime.utc_now(), -window_minutes * 60, :second)

    with {:ok, recent_kills} <- get_recent_kills(system_id, cutoff) do
      escalation_indicators = %{
        participant_growth: analyze_participant_growth(recent_kills),
        ship_class_escalation: analyze_ship_escalation(recent_kills),
        alliance_involvement: analyze_alliance_involvement(recent_kills),
        isk_escalation: analyze_isk_escalation(recent_kills),
        geographic_spread: analyze_geographic_spread(recent_kills)
      }

      risk_score = calculate_escalation_risk(escalation_indicators)

      {:ok,
       %{
         system_id: system_id,
         monitoring_window: window_minutes,
         indicators: escalation_indicators,
         risk_score: risk_score,
         risk_level: classify_risk_level(risk_score),
         recommended_action: recommend_action(risk_score, escalation_indicators),
         predicted_peak: predict_peak_time(recent_kills, escalation_indicators)
       }}
    end
  end

  defp build_timeframe(opts) do
    default_hours = Keyword.get(opts, :hours, 24)
    default_days = Keyword.get(opts, :days, 0)

    total_hours = default_hours + default_days * 24

    %{
      start_time: DateTime.add(DateTime.utc_now(), -total_hours * 3600, :second),
      end_time: DateTime.utc_now(),
      duration_hours: total_hours
    }
  end

  defp get_scoped_killmails(scope, timeframe) do
    query =
      KillmailRaw
      |> filter(killmail_time >= ^timeframe.start_time)
      |> filter(killmail_time <= ^timeframe.end_time)

    final_query =
      case scope do
        {:system, system_id} ->
          query |> filter(solar_system_id == ^system_id)

        _ ->
          # Only system-level analysis is supported currently
          {:error, :scope_not_supported}
      end

    case final_query do
      {:error, _} = error ->
        error

      valid_query ->
        killmails =
          valid_query
          |> select([
            :killmail_id,
            :killmail_time,
            :solar_system_id,
            :total_value,
            :victim_character_id,
            :victim_ship_type_id,
            :data
          ])
          |> Ash.read!(domain: EveDmv.Api)

        {:ok, killmails}
    end
  rescue
    error ->
      {:error, {:killmail_query_failed, error}}
  end

  defp get_recent_kills(system_id, cutoff) do
    killmails =
      KillmailRaw
      |> filter(solar_system_id == ^system_id)
      |> filter(killmail_time >= ^cutoff)
      |> select([
        :killmail_id,
        :killmail_time,
        :total_value,
        :victim_character_id,
        :victim_ship_type_id,
        :data
      ])
      |> Ash.read!(domain: EveDmv.Api)

    {:ok, killmails}
  rescue
    error ->
      {:error, {:recent_kills_query_failed, error}}
  end

  defp identify_escalation_windows(killmails) do
    # Sort by time
    sorted = Enum.sort_by(killmails, & &1.killmail_time)

    # Group into windows with < 10 min gaps
    Enum.reduce(sorted, [], fn kill, acc ->
      case acc do
        [] ->
          [[kill]]

        [current_window | rest] ->
          last_kill = List.last(current_window)
          time_diff = DateTime.diff(kill.killmail_time, last_kill.killmail_time, :second)

          # 10 minutes
          if time_diff <= 600 do
            [[kill | current_window] | rest]
          else
            [[kill] | [current_window | rest]]
          end
      end
    end)
    # At least 3 kills
    |> Enum.filter(fn window -> length(window) >= 3 end)
  end

  defp analyze_escalation_window(window) do
    # Sort chronologically
    sorted = Enum.sort_by(window, & &1.killmail_time)

    # Analyze progression
    phases = divide_into_phases(sorted)

    escalation_metrics = %{
      duration: calculate_duration(sorted),
      phases: length(phases),
      participant_growth: analyze_participant_progression(phases),
      ship_progression: analyze_ship_progression(phases),
      intensity_curve: calculate_intensity_curve(phases),
      peak_phase: identify_peak_phase(phases),
      de_escalation: detect_de_escalation(phases)
    }

    is_escalation = determine_if_escalation(escalation_metrics)

    %{
      start_time: List.first(sorted).killmail_time,
      end_time: List.last(sorted).killmail_time,
      system_id: List.first(sorted).solar_system_id,
      total_kills: length(window),
      is_escalation: is_escalation,
      metrics: escalation_metrics,
      classification: classify_escalation(escalation_metrics),
      timeline: build_escalation_timeline(phases)
    }
  end

  defp divide_into_phases(killmails) do
    # Divide into phases based on time gaps
    phases =
      Enum.chunk_by(killmails, fn kill ->
        # Group by 5-minute intervals
        DateTime.to_unix(kill.killmail_time, :second) |> div(300)
      end)

    phases
  end

  defp calculate_duration(killmails) do
    case killmails do
      [] ->
        0

      [_single] ->
        0

      multiple ->
        first = List.first(multiple)
        last = List.last(multiple)
        DateTime.diff(last.killmail_time, first.killmail_time, :second)
    end
  end

  defp analyze_participant_progression(phases) do
    # Analyze how participant count changes over time
    participant_counts =
      Enum.map(phases, fn phase ->
        unique_participants =
          phase
          |> Enum.flat_map(fn kill ->
            attackers =
              case kill.data do
                %{"attackers" => attackers} when is_list(attackers) ->
                  Enum.map(attackers, & &1["character_id"])

                _ ->
                  []
              end

            victim_id = kill.victim_character_id

            [victim_id | attackers]
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()
          |> length()

        %{
          # Phase number
          phase: length(phases) - length(phases) + 1,
          participants: unique_participants
        }
      end)

    # Calculate growth rate
    growth_rate = calculate_growth_rate(participant_counts)

    %{
      initial_count: List.first(participant_counts).participants,
      peak_count: Enum.max_by(participant_counts, & &1.participants).participants,
      final_count: List.last(participant_counts).participants,
      growth_rate: growth_rate,
      growth_pattern: classify_growth_pattern(participant_counts)
    }
  end

  defp analyze_ship_progression(phases) do
    # Track progression from smaller to larger ships
    ship_progression =
      Enum.with_index(phases, 1)
      |> Enum.map(fn {phase, phase_num} ->
        ships =
          Enum.flat_map(phase, fn kill ->
            victim_ship = kill.victim_ship_type_id

            attacker_ships =
              case kill.data do
                %{"attackers" => attackers} when is_list(attackers) ->
                  Enum.map(attackers, & &1["ship_type_id"])

                _ ->
                  []
              end

            [victim_ship | attacker_ships]
          end)
          |> Enum.reject(&is_nil/1)

        %{
          phase: phase_num,
          average_class: calculate_average_ship_class(ships),
          max_class: determine_max_ship_class(ships),
          capital_present: has_capitals?(ships)
        }
      end)

    %{
      progression: ship_progression,
      escalated_to_capitals: Enum.any?(ship_progression, & &1.capital_present),
      max_ship_class: Enum.max_by(ship_progression, & &1.max_class).max_class,
      escalation_velocity: calculate_ship_escalation_velocity(ship_progression)
    }
  end

  defp calculate_intensity_curve(phases) do
    # Calculate intensity for each phase
    Enum.with_index(phases, 1)
    |> Enum.map(fn {phase, phase_num} ->
      kill_count = length(phase)
      total_value = phase |> Enum.map(&(&1.total_value || 0)) |> Enum.sum()

      %{
        phase: phase_num,
        kill_count: kill_count,
        total_value: total_value,
        # Normalize billions
        intensity: kill_count + total_value / 1_000_000_000
      }
    end)
  end

  defp identify_peak_phase(phases) do
    phases
    |> Enum.with_index(1)
    |> Enum.max_by(fn {phase, _num} -> length(phase) end)
    # Return phase number
    |> elem(1)
  end

  defp detect_de_escalation(phases) do
    if length(phases) < 3 do
      false
    else
      # Check if last phase has significantly fewer kills than peak
      phase_sizes = Enum.map(phases, &length/1)
      peak_size = Enum.max(phase_sizes)
      last_size = List.last(phase_sizes)

      last_size < peak_size * 0.5
    end
  end

  defp determine_if_escalation(metrics) do
    # Determine if this qualifies as an escalation
    escalation_indicators = [
      # 20% growth
      metrics.participant_growth.growth_rate > 0.2,
      # Multiple phases
      metrics.phases >= 2,
      # At least 5 minutes
      metrics.duration > 300,
      metrics.ship_progression.escalated_to_capitals
    ]

    # Need at least 2 indicators for escalation
    Enum.count(escalation_indicators, & &1) >= 2
  end

  defp classify_escalation(metrics) do
    cond do
      metrics.ship_progression.escalated_to_capitals -> :capital_escalation
      metrics.participant_growth.peak_count > 50 -> :major_escalation
      metrics.participant_growth.peak_count > 20 -> :moderate_escalation
      metrics.phases > 3 -> :prolonged_escalation
      true -> :minor_escalation
    end
  end

  defp build_escalation_timeline(phases) do
    Enum.with_index(phases, 1)
    |> Enum.map(fn {phase, phase_num} ->
      first_kill = List.first(phase)
      last_kill = List.last(phase)

      %{
        phase: phase_num,
        start_time: first_kill.killmail_time,
        end_time: last_kill.killmail_time,
        kill_count: length(phase),
        participants: count_unique_participants(phase),
        key_events: identify_key_events(phase)
      }
    end)
  end

  # Real-time monitoring analysis functions

  defp analyze_participant_growth(killmails) do
    if length(killmails) < 2 do
      %{growth_rate: 0, trend: :stable}
    else
      # Analyze participant growth over time windows
      time_windows = chunk_by_time(killmails, minutes: 5)

      participant_counts =
        Enum.map(time_windows, fn window ->
          count_unique_participants(window)
        end)

      growth_rate =
        case participant_counts do
          [] ->
            0

          [_single] ->
            0

          multiple ->
            first = List.first(multiple)
            last = List.last(multiple)
            if first > 0, do: (last - first) / first, else: 0
        end

      %{
        growth_rate: growth_rate,
        trend: classify_trend(growth_rate),
        current_participants: List.last(participant_counts) || 0,
        peak_participants: Enum.max(participant_counts)
      }
    end
  end

  defp analyze_ship_escalation(killmails) do
    # Track progression of ship classes over time
    time_windows = chunk_by_time(killmails, minutes: 5)

    ship_progression =
      Enum.map(time_windows, fn window ->
        ships =
          Enum.flat_map(window, fn kill ->
            victim_ship = kill.victim_ship_type_id

            attacker_ships =
              case kill.data do
                %{"attackers" => attackers} when is_list(attackers) ->
                  Enum.map(attackers, & &1["ship_type_id"])

                _ ->
                  []
              end

            [victim_ship | attacker_ships]
          end)
          |> Enum.reject(&is_nil/1)

        %{
          average_class: calculate_average_ship_class(ships),
          max_class: determine_max_ship_class(ships),
          capital_present: has_capitals?(ships)
        }
      end)

    %{
      progression: ship_progression,
      escalated_to_capitals: Enum.any?(ship_progression, & &1.capital_present),
      escalation_velocity: calculate_ship_escalation_velocity(ship_progression),
      current_max_class: List.last(ship_progression).max_class
    }
  end

  defp analyze_alliance_involvement(killmails) do
    # Track alliance participation growth
    time_windows = chunk_by_time(killmails, minutes: 5)

    alliance_progression =
      Enum.map(time_windows, fn window ->
        alliances =
          window
          |> Enum.flat_map(fn kill ->
            victim_alliance =
              case kill.data do
                %{"victim" => %{"alliance_id" => alliance_id}} -> [alliance_id]
                _ -> []
              end

            attacker_alliances =
              case kill.data do
                %{"attackers" => attackers} when is_list(attackers) ->
                  attackers
                  |> Enum.map(& &1["alliance_id"])
                  |> Enum.reject(&is_nil/1)

                _ ->
                  []
              end

            victim_alliance ++ attacker_alliances
          end)
          |> Enum.reject(&is_nil/1)
          |> Enum.uniq()

        length(alliances)
      end)

    %{
      initial_alliances: List.first(alliance_progression) || 0,
      peak_alliances: Enum.max(alliance_progression),
      current_alliances: List.last(alliance_progression) || 0,
      major_alliance_joined: detect_major_alliance_entry(alliance_progression)
    }
  end

  defp analyze_isk_escalation(killmails) do
    # Track ISK value escalation
    time_windows = chunk_by_time(killmails, minutes: 5)

    isk_progression =
      Enum.map(time_windows, fn window ->
        window
        |> Enum.map(&(&1.total_value || 0))
        |> Enum.sum()
      end)

    %{
      total_isk: Enum.sum(isk_progression),
      peak_window_isk: Enum.max(isk_progression),
      isk_trend: classify_trend_from_values(isk_progression),
      high_value_kills: count_high_value_kills(killmails)
    }
  end

  defp analyze_geographic_spread(killmails) do
    # Analyze if conflict is spreading to other systems
    systems =
      killmails
      |> Enum.map(& &1.solar_system_id)
      |> Enum.uniq()

    %{
      systems_involved: length(systems),
      primary_system: find_primary_system(killmails),
      spread_factor: calculate_spread_factor(killmails, systems)
    }
  end

  defp calculate_escalation_risk(indicators) do
    # Weighted risk calculation
    weights = %{
      participant_growth: 0.25,
      ship_class_escalation: 0.30,
      alliance_involvement: 0.20,
      isk_escalation: 0.15,
      geographic_spread: 0.10
    }

    participant_risk = calculate_participant_risk(indicators.participant_growth)
    ship_risk = calculate_ship_risk(indicators.ship_class_escalation)
    alliance_risk = calculate_alliance_risk(indicators.alliance_involvement)
    isk_risk = calculate_isk_risk(indicators.isk_escalation)
    geographic_risk = calculate_geographic_risk(indicators.geographic_spread)

    weighted_risk =
      participant_risk * weights.participant_growth +
        ship_risk * weights.ship_class_escalation +
        alliance_risk * weights.alliance_involvement +
        isk_risk * weights.isk_escalation +
        geographic_risk * weights.geographic_spread

    min(100, weighted_risk)
  end

  # Helper functions

  defp chunk_by_time(killmails, minutes: interval) do
    killmails
    |> Enum.group_by(fn kill ->
      DateTime.to_unix(kill.killmail_time, :second) |> div(interval * 60)
    end)
    |> Map.values()
  end

  defp count_unique_participants(killmails) do
    killmails
    |> Enum.flat_map(fn kill ->
      attackers =
        case kill.data do
          %{"attackers" => attackers} when is_list(attackers) ->
            Enum.map(attackers, & &1["character_id"])

          _ ->
            []
        end

      [kill.victim_character_id | attackers]
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> length()
  end

  defp calculate_average_ship_class(ship_type_ids) do
    # Use real ship classification from EVE static data
    alias EveDmv.StaticData.ShipTypes

    scores =
      Enum.map(ship_type_ids, fn type_id ->
        case ShipTypes.classify_ship_type(type_id) do
          :frigate -> 1
          :destroyer -> 1.5
          :cruiser -> 2
          :battlecruiser -> 2.5
          :battleship -> 3
          :capital -> 4
          :supercapital -> 5
          # Default to frigate equivalent
          _ -> 1
        end
      end)

    case scores do
      [] -> 0
      list -> Enum.sum(list) / length(list)
    end
  end

  defp determine_max_ship_class(ship_type_ids) do
    # Use real ship classification from EVE static data
    alias EveDmv.StaticData.ShipTypes

    ship_type_ids
    |> Enum.map(fn type_id ->
      case ShipTypes.classify_ship_type(type_id) do
        :frigate -> 1
        :destroyer -> 1.5
        :cruiser -> 2
        :battlecruiser -> 2.5
        :battleship -> 3
        :capital -> 4
        :supercapital -> 5
        # Default to frigate equivalent
        _ -> 1
      end
    end)
    |> Enum.max(fn -> 0 end)
  end

  defp has_capitals?(ship_type_ids) do
    # Use real ship classification from EVE static data
    alias EveDmv.StaticData.ShipTypes

    Enum.any?(ship_type_ids, fn type_id ->
      case ShipTypes.classify_ship_type(type_id) do
        :capital -> true
        :supercapital -> true
        _ -> false
      end
    end)
  end

  defp calculate_growth_rate(participant_counts) do
    case participant_counts do
      [] ->
        0

      [_single] ->
        0

      multiple ->
        first = List.first(multiple).participants
        last = List.last(multiple).participants
        if first > 0, do: (last - first) / first, else: 0
    end
  end

  defp classify_growth_pattern(participant_counts) do
    if length(participant_counts) < 3 do
      :insufficient_data
    else
      counts = Enum.map(participant_counts, & &1.participants)

      cond do
        increasing_pattern?(counts) -> :escalating
        decreasing_pattern?(counts) -> :de_escalating
        stable_pattern?(counts) -> :stable
        true -> :volatile
      end
    end
  end

  defp calculate_ship_escalation_velocity(ship_progression) do
    case ship_progression do
      [] ->
        0

      [_single] ->
        0

      multiple ->
        first = List.first(multiple).max_class
        last = List.last(multiple).max_class
        phases = length(multiple)
        (last - first) / phases
    end
  end

  defp identify_key_events(phase) do
    # Identify significant events in phase
    alias EveDmv.StaticData.ShipTypes

    # Check for first capital kill using real ship classification
    capital_events =
      if Enum.any?(phase, fn kill ->
           case ShipTypes.classify_ship_type(kill.victim_ship_type_id) do
             :capital -> true
             :supercapital -> true
             _ -> false
           end
         end) do
        ["first_capital_kill"]
      else
        []
      end

    # Check for high-value kills
    high_value_events =
      if Enum.any?(phase, fn kill ->
           (kill.total_value || 0) > 1_000_000_000
         end) do
        ["high_value_kill"]
      else
        []
      end

    capital_events ++ high_value_events
  end

  defp assess_current_risk(killmails) do
    recent_activity = length(killmails)
    high_value_kills = count_high_value_kills(killmails)

    cond do
      recent_activity > 50 and high_value_kills > 5 -> :critical
      recent_activity > 20 and high_value_kills > 2 -> :high
      recent_activity > 10 -> :moderate
      recent_activity > 0 -> :low
      true -> :minimal
    end
  end

  defp predict_future_escalations(escalations, killmails) do
    # Prediction based on actual escalation patterns
    active_escalations = length(escalations)
    recent_activity = length(killmails)

    # Calculate probability based on multiple factors
    base_probability = min(active_escalations * 15, 70)
    activity_modifier = min(recent_activity / 10 * 10, 20)

    probability = min(base_probability + activity_modifier, 85)

    # Calculate confidence based on data quality
    confidence =
      cond do
        recent_activity >= 20 -> 0.8
        recent_activity >= 10 -> 0.7
        recent_activity >= 5 -> 0.6
        true -> 0.4
      end

    %{
      probability: round(probability),
      timeframe: "next_2_hours",
      confidence: confidence
    }
  end

  defp classify_risk_level(risk_score) do
    cond do
      risk_score >= 80 -> :critical
      risk_score >= 60 -> :high
      risk_score >= 40 -> :moderate
      risk_score >= 20 -> :low
      true -> :minimal
    end
  end

  defp recommend_action(risk_score, indicators) do
    cond do
      risk_score >= 80 ->
        "CRITICAL: Major escalation in progress. Large fleet engagement likely."

      risk_score >= 60 and indicators.ship_class_escalation.escalated_to_capitals ->
        "HIGH: Capital escalation detected. Monitor for supercapital involvement."

      risk_score >= 60 ->
        "HIGH: Rapid escalation detected. Additional forces being deployed."

      risk_score >= 40 ->
        "MODERATE: Conflict expanding. Watch for alliance-level response."

      risk_score >= 20 ->
        "LOW: Small-scale engagement. May develop further."

      true ->
        "MINIMAL: Isolated incident. No escalation expected."
    end
  end

  defp predict_peak_time(recent_kills, indicators) do
    # Predict when escalation will peak based on current trajectory
    growth_rate = indicators.participant_growth.growth_rate

    if growth_rate > 0 do
      # Estimate time to peak based on growth rate
      minutes_to_peak = estimate_peak_time(growth_rate, recent_kills)
      DateTime.add(DateTime.utc_now(), minutes_to_peak * 60, :second)
    else
      nil
    end
  end

  defp estimate_peak_time(growth_rate, recent_kills) do
    # Simplified peak time estimation
    # 30 minutes base
    base_time = 30
    # Up to 2x modifier
    activity_modifier = min(length(recent_kills) / 10, 2)
    # Up to 1.5x modifier
    growth_modifier = min(growth_rate * 100, 1.5)

    trunc(base_time / (activity_modifier * growth_modifier))
  end

  # Risk calculation helpers

  defp calculate_participant_risk(growth_data) do
    base_risk = growth_data.current_participants * 2
    growth_bonus = growth_data.growth_rate * 50

    min(100, base_risk + growth_bonus)
  end

  defp calculate_ship_risk(ship_data) do
    base_risk = ship_data.current_max_class * 20
    capital_bonus = if ship_data.escalated_to_capitals, do: 40, else: 0

    min(100, base_risk + capital_bonus)
  end

  defp calculate_alliance_risk(alliance_data) do
    min(100, alliance_data.current_alliances * 15)
  end

  defp calculate_isk_risk(isk_data) do
    # ISK in billions
    isk_billions = isk_data.total_isk / 1_000_000_000
    base_risk = min(60, isk_billions * 2)
    high_value_bonus = isk_data.high_value_kills * 5

    min(100, base_risk + high_value_bonus)
  end

  defp calculate_geographic_risk(geo_data) do
    min(100, geo_data.systems_involved * 10 + geo_data.spread_factor * 20)
  end

  # Utility functions

  defp classify_trend(growth_rate) do
    cond do
      growth_rate > 0.1 -> :increasing
      growth_rate < -0.1 -> :decreasing
      true -> :stable
    end
  end

  defp classify_trend_from_values(values) do
    case values do
      [] ->
        :stable

      [_single] ->
        :stable

      multiple ->
        first = List.first(multiple)
        last = List.last(multiple)

        if first == 0 do
          :stable
        else
          change = (last - first) / first
          classify_trend(change)
        end
    end
  end

  defp detect_major_alliance_entry(alliance_progression) do
    case alliance_progression do
      [] ->
        false

      [_single] ->
        false

      multiple ->
        max_diff =
          multiple
          |> Enum.chunk_every(2, 1, :discard)
          |> Enum.map(fn [a, b] -> b - a end)
          |> Enum.max()

        # 3+ new alliances in one window
        max_diff >= 3
    end
  end

  defp count_high_value_kills(killmails) do
    Enum.count(killmails, fn kill ->
      # 1B ISK
      (kill.total_value || 0) > 1_000_000_000
    end)
  end

  defp find_primary_system(killmails) do
    killmails
    |> Enum.frequencies_by(& &1.solar_system_id)
    |> Enum.max_by(fn {_system, count} -> count end, fn -> {nil, 0} end)
    |> elem(0)
  end

  defp calculate_spread_factor(killmails, systems) do
    if length(systems) <= 1 do
      0
    else
      # Calculate how evenly distributed activity is across systems
      system_counts =
        killmails
        |> Enum.frequencies_by(& &1.solar_system_id)
        |> Map.values()

      max_count = Enum.max(system_counts)
      min_count = Enum.min(system_counts)

      if max_count == 0, do: 0, else: min_count / max_count
    end
  end

  defp increasing_pattern?(counts) do
    counts
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] -> b >= a end)
  end

  defp decreasing_pattern?(counts) do
    counts
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] -> b <= a end)
  end

  defp stable_pattern?(counts) do
    max_val = Enum.max(counts)
    min_val = Enum.min(counts)

    if max_val == 0, do: true, else: (max_val - min_val) / max_val < 0.2
  end
end
