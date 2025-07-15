defmodule EveDmv.Contexts.BattleAnalysis.Domain.EnhancedCombatLogParser do
  @moduledoc """
  Enhanced parser for EVE Online combat logs with comprehensive tactical analysis.

  Extracts detailed combat information including:
  - Outgoing and incoming damage with hit quality analysis
  - Module activations (weapons, ewar, defensive, tackle)
  - Tactical patterns (target selection, defensive reactions)
  - Range management and application efficiency
  - Module usage effectiveness
  """

  require Logger

  @doc """
  Parses a combat log file and extracts comprehensive combat events.

  ## Returns
  {:ok, %{
    events: [combat_event],
    tactical_analysis: %{...},
    summary: %{...},
    recommendations: [...]
  }}
  """
  def parse_combat_log(content, options \\ []) do
    lines = String.split(content, "\n", trim: true)

    events =
      lines
      |> Enum.map(&parse_line/1)
      |> Enum.filter(&(&1 != nil))
      |> filter_by_time(options[:start_time], options[:end_time])
      |> filter_by_pilot(options[:pilot_name])

    tactical_analysis = analyze_tactical_patterns(events)
    summary = generate_enhanced_summary(events, options[:pilot_name])
    recommendations = generate_tactical_recommendations(tactical_analysis, events)

    {:ok,
     %{
       events: events,
       tactical_analysis: tactical_analysis,
       summary: summary,
       recommendations: recommendations,
       metadata: extract_metadata(events)
     }}
  end

  @doc """
  Correlates combat log with fitting data to analyze module usage effectiveness.
  """
  def analyze_fitting_vs_usage(events, fitting_data) do
    if fitting_data do
      %{
        module_usage_analysis: analyze_fitted_module_usage(events, fitting_data),
        unused_modules: identify_unused_modules(events, fitting_data),
        optimization_suggestions: suggest_fitting_improvements(events, fitting_data),
        tactical_effectiveness: rate_fitting_effectiveness(events, fitting_data)
      }
    else
      %{error: "No fitting data available for analysis"}
    end
  end

  # Private parsing functions

  defp parse_line(line) do
    cond do
      # Outgoing damage: "278 to Darin Raltin[GI.N](Porpoise) - Scourge Rage Rocket - Hits"
      String.contains?(line, "\tCombat\t") &&
          Regex.match?(
            ~r/\d+ to [^\[]+\[[^\]]+\]\([^\)]+\) - [^-]+ - (Hits|Penetrates|Smashes|Wrecks|Glances Off|Grazes)/,
            line
          ) ->
        parse_outgoing_damage_line(line)

      # Incoming damage: "15 from Kragden[GI.N](Covetor) - Hornet II - Glances Off"
      String.contains?(line, "\tCombat\t") &&
          Regex.match?(
            ~r/\d+ from [^\[]+\[[^\]]+\]\([^\)]+\) - [^-]+ - (Hits|Penetrates|Smashes|Wrecks|Glances Off|Grazes)/,
            line
          ) ->
        parse_incoming_damage_line(line)

      # Miss patterns: "Hornet II belonging to Nitlar Nirad misses you completely"
      String.contains?(line, "\tCombat\t") && String.contains?(line, "misses") &&
          String.contains?(line, "completely") ->
        parse_miss_line(line)

      # Module attempts: "Warp scramble attempt from you to"
      String.contains?(line, "\tCombat\t") &&
          Regex.match?(~r/(Warp scramble|Warp disruption) attempt/, line) ->
        parse_tackle_attempt_line(line)

      # Energy warfare: "-0 GJ energy drained to [Brutix]"
      String.contains?(line, "\tCombat\t") && String.contains?(line, "energy drained") ->
        parse_energy_drain_line(line)

      # Range failures: "Your target is too far away"
      String.contains?(line, "\tCombat\t") && String.contains?(line, "too far away") ->
        parse_range_failure_line(line)

      # Defensive modules: "Shield booster activated", "Armor repair activated"
      String.contains?(line, "\tCombat\t") &&
          Regex.match?(~r/(Shield booster|Armor repair|Hull repair|Ancillary) activated/, line) ->
        parse_defensive_module_line(line)

      # Module overheating: "Your modules are overheating"
      String.contains?(line, "\tCombat\t") && String.contains?(line, "overheating") ->
        parse_overheat_line(line)

      # Capacitor warnings: "Your capacitor is empty"
      String.contains?(line, "\tCombat\t") && String.contains?(line, "capacitor") ->
        parse_capacitor_line(line)

      # Generic combat events
      String.contains?(line, "\tCombat\t") ->
        parse_combat_line(line)

      # Session changes
      String.contains?(line, "\tNotify\t") && String.contains?(line, "Session change") ->
        parse_session_line(line)

      true ->
        nil
    end
  end

  defp parse_outgoing_damage_line(line) do
    timestamp = extract_timestamp(line)

    # Parse format: "04:30:16\tCombat\t278 to Darin Raltin[GI.N](Porpoise) - Scourge Rage Rocket - Hits"
    case Regex.run(~r/\t(\d+) to ([^\[]+)\[([^\]]+)\]\(([^\)]+)\) - ([^-]+) - ([^\t\n\r]+)/, line) do
      [_, damage_str, target_name, target_corp, target_ship, weapon, quality_str] ->
        damage = String.to_integer(damage_str)
        quality = parse_hit_quality(String.trim(quality_str))

        %{
          type: :damage_dealt,
          timestamp: timestamp,
          damage: damage,
          target: String.trim(target_name),
          target_corp: String.trim(target_corp),
          target_ship: String.trim(target_ship),
          weapon: String.trim(weapon),
          hit_quality: quality,
          application_percentage: calculate_application_percentage(quality)
        }

      _ ->
        nil
    end
  end

  defp parse_incoming_damage_line(line) do
    timestamp = extract_timestamp(line)

    # Parse format: "04:27:08\tCombat\t15 from Kragden[GI.N](Covetor) - Hornet II - Glances Off"
    case Regex.run(
           ~r/\t(\d+) from ([^\[]+)\[([^\]]+)\]\(([^\)]+)\) - ([^-]+) - ([^\t\n\r]+)/,
           line
         ) do
      [_, damage_str, attacker_name, attacker_corp, attacker_ship, weapon, quality_str] ->
        damage = String.to_integer(damage_str)
        quality = parse_hit_quality(String.trim(quality_str))

        %{
          type: :damage_received,
          timestamp: timestamp,
          damage: damage,
          attacker: String.trim(attacker_name),
          attacker_corp: String.trim(attacker_corp),
          attacker_ship: String.trim(attacker_ship),
          weapon: String.trim(weapon),
          hit_quality: quality,
          application_percentage: calculate_application_percentage(quality)
        }

      _ ->
        nil
    end
  end

  defp parse_miss_line(line) do
    timestamp = extract_timestamp(line)

    # Parse format: "Valkyrie II belonging to Darin Raltin misses you completely - Valkyrie II"
    case Regex.run(~r/([^\s]+) belonging to ([^\s]+) misses you completely - ([^\t\n\r]+)/, line) do
      [_, _weapon, attacker, weapon_type] ->
        %{
          type: :miss_received,
          timestamp: timestamp,
          attacker: String.trim(attacker),
          weapon: String.trim(weapon_type),
          damage: 0,
          hit_quality: :miss
        }

      _ ->
        nil
    end
  end

  defp parse_tackle_attempt_line(line) do
    timestamp = extract_timestamp(line)

    # Parse patterns like "Warp scramble attempt from you to" or "Warp disruption attempt from"
    cond do
      String.contains?(line, "attempt from you to") ->
        # Outgoing tackle attempt
        module_type =
          cond do
            String.contains?(line, "Warp scramble") -> "Warp Scrambler"
            String.contains?(line, "Warp disruption") -> "Warp Disruptor"
            true -> "Tackle Module"
          end

        %{
          type: :tackle_attempt,
          timestamp: timestamp,
          module: module_type,
          direction: :outgoing,
          # Will be determined by follow-up events
          success: nil
        }

      String.contains?(line, "attempt from") ->
        # Incoming tackle attempt
        module_type =
          cond do
            String.contains?(line, "Warp scramble") -> "Warp Scrambler"
            String.contains?(line, "Warp disruption") -> "Warp Disruptor"
            true -> "Tackle Module"
          end

        %{
          type: :tackle_received,
          timestamp: timestamp,
          module: module_type,
          direction: :incoming
        }

      true ->
        nil
    end
  end

  defp parse_energy_drain_line(line) do
    timestamp = extract_timestamp(line)

    # Parse format: "04:35:03\tCombat\t-0 GJ energy drained to [Brutix] Kragden |[GI.N] - Medium Energy Nosferatu II"
    case Regex.run(
           ~r/\t-?(\d+) GJ energy drained to \[([^\]]+)\]\s*([^\-]+) - ([^\t\n\r]+)/,
           line
         ) do
      [_, energy_str, target_ship, target_name, module] ->
        %{
          type: :energy_warfare,
          timestamp: timestamp,
          module: String.trim(module),
          energy_amount: String.to_integer(energy_str),
          target: String.trim(target_name),
          target_ship: String.trim(target_ship),
          direction: :outgoing
        }

      _ ->
        nil
    end
  end

  defp parse_range_failure_line(line) do
    timestamp = extract_timestamp(line)

    %{
      type: :range_failure,
      timestamp: timestamp,
      reason: "Target too far away",
      action: extract_failed_action(line)
    }
  end

  defp parse_defensive_module_line(line) do
    timestamp = extract_timestamp(line)

    module_type =
      cond do
        String.contains?(line, "Shield booster") -> "Shield Booster"
        String.contains?(line, "Armor repair") -> "Armor Repairer"
        String.contains?(line, "Hull repair") -> "Hull Repairer"
        String.contains?(line, "Ancillary") -> "Ancillary Module"
        true -> "Defensive Module"
      end

    %{
      type: :defensive_module,
      timestamp: timestamp,
      module: module_type,
      # Assume triggered by damage
      trigger: :damage_response
    }
  end

  defp parse_overheat_line(line) do
    timestamp = extract_timestamp(line)

    %{
      type: :overheat_warning,
      timestamp: timestamp,
      message: "Modules overheating"
    }
  end

  defp parse_capacitor_line(line) do
    timestamp = extract_timestamp(line)

    warning_type =
      cond do
        String.contains?(line, "capacitor is empty") -> :cap_empty
        String.contains?(line, "capacitor is low") -> :cap_low
        true -> :cap_warning
      end

    %{
      type: :capacitor_warning,
      timestamp: timestamp,
      warning_type: warning_type
    }
  end

  defp parse_combat_line(line) do
    timestamp = extract_timestamp(line)

    # Generic combat event that doesn't match other patterns
    content =
      line
      |> String.replace(~r/^[^\t]*\tCombat\t/, "")
      |> String.trim()

    %{
      type: :combat,
      timestamp: timestamp,
      action: content
    }
  end

  defp parse_session_line(line) do
    timestamp = extract_timestamp(line)

    # Extract session change info
    action =
      case Regex.run(~r/Session change: (.+)$/, line) do
        [_, a] -> a
        _ -> "Unknown"
      end

    %{
      type: :session,
      timestamp: timestamp,
      action: action
    }
  end

  # Tactical Analysis Functions

  defp analyze_tactical_patterns(events) do
    %{
      damage_application: analyze_damage_application(events),
      tackle_effectiveness: analyze_tackle_effectiveness(events),
      defensive_reactions: analyze_defensive_reactions(events),
      range_management: analyze_range_management(events),
      target_selection: analyze_target_selection(events),
      module_usage: analyze_module_usage_patterns(events),
      survivability: analyze_survivability_patterns(events)
    }
  end

  defp analyze_damage_application(events) do
    damage_events = Enum.filter(events, &(&1.type == :damage_dealt))

    if length(damage_events) > 0 do
      quality_breakdown =
        damage_events
        |> Enum.group_by(& &1.hit_quality)
        |> Enum.map(fn {quality, events} ->
          {quality,
           %{
             count: length(events),
             percentage: length(events) / length(damage_events) * 100,
             total_damage: Enum.sum(Enum.map(events, & &1.damage)),
             avg_damage: Float.round(Enum.sum(Enum.map(events, & &1.damage)) / length(events), 1)
           }}
        end)
        |> Enum.into(%{})

      avg_application =
        damage_events
        |> Enum.map(& &1.application_percentage)
        |> Enum.sum()
        |> Kernel./(length(damage_events))
        |> Float.round(1)

      %{
        total_shots: length(damage_events),
        average_application: avg_application,
        quality_breakdown: quality_breakdown,
        weapon_performance: analyze_weapon_performance(damage_events),
        target_analysis: analyze_target_difficulty(damage_events)
      }
    else
      %{total_shots: 0, average_application: 0}
    end
  end

  defp analyze_tackle_effectiveness(events) do
    tackle_attempts = Enum.filter(events, &(&1.type == :tackle_attempt))
    tackle_received = Enum.filter(events, &(&1.type == :tackle_received))

    %{
      tackle_attempts: length(tackle_attempts),
      tackle_received: length(tackle_received),
      tackle_modules_used: tackle_attempts |> Enum.map(& &1.module) |> Enum.uniq(),
      tackle_timing: analyze_tackle_timing(tackle_attempts, events)
    }
  end

  defp analyze_defensive_reactions(events) do
    defensive_activations = Enum.filter(events, &(&1.type == :defensive_module))
    damage_received = Enum.filter(events, &(&1.type == :damage_received))

    reaction_times = calculate_defensive_reaction_times(defensive_activations, damage_received)

    %{
      defensive_activations: length(defensive_activations),
      modules_used: defensive_activations |> Enum.map(& &1.module) |> Enum.uniq(),
      average_reaction_time: Enum.sum(reaction_times) / max(length(reaction_times), 1),
      damage_before_defense:
        calculate_damage_before_defense(defensive_activations, damage_received)
    }
  end

  defp analyze_range_management(events) do
    range_failures = Enum.filter(events, &(&1.type == :range_failure))

    %{
      range_failures: length(range_failures),
      range_discipline_score: calculate_range_discipline_score(events),
      failed_actions: range_failures |> Enum.map(& &1.action) |> Enum.frequencies()
    }
  end

  defp analyze_target_selection(events) do
    damage_events = Enum.filter(events, &(&1.type == :damage_dealt))

    target_stats =
      damage_events
      |> Enum.group_by(& &1.target)
      |> Enum.map(fn {target, target_events} ->
        {target,
         %{
           shots: length(target_events),
           damage: Enum.sum(Enum.map(target_events, & &1.damage)),
           avg_application:
             Enum.sum(Enum.map(target_events, & &1.application_percentage)) /
               length(target_events),
           ship_type: List.first(target_events).target_ship
         }}
      end)
      |> Enum.into(%{})

    %{
      targets_engaged: length(Map.keys(target_stats)),
      target_statistics: target_stats,
      target_prioritization: rate_target_prioritization(target_stats)
    }
  end

  # Fitting Correlation Analysis

  defp analyze_fitted_module_usage(events, fitting_data) do
    fitted_modules = extract_modules_from_fitting(fitting_data)
    used_modules = extract_used_modules_from_events(events)

    Enum.map(fitted_modules, fn module ->
      usage_stats = used_modules[module[:type_name]] || %{activations: 0, effectiveness: 0}

      %{
        module: module,
        fitted: true,
        used: usage_stats.activations > 0,
        activations: usage_stats.activations,
        effectiveness: usage_stats.effectiveness,
        recommendation: recommend_module_usage(module, usage_stats)
      }
    end)
  end

  defp identify_unused_modules(events, fitting_data) do
    fitted_modules = extract_modules_from_fitting(fitting_data)
    used_module_types = events |> extract_used_modules_from_events() |> Map.keys()

    fitted_modules
    |> Enum.filter(fn module ->
      not Enum.member?(used_module_types, module[:type_name])
    end)
    |> Enum.map(fn module ->
      %{
        module: module,
        reason: determine_unused_reason(module, events),
        suggestion: suggest_usage_improvement(module, events)
      }
    end)
  end

  # Helper Functions

  defp extract_timestamp(line) do
    # Extract timestamp from line: 04:27:08\tCombat\t...
    case Regex.run(~r/^(\d{2}:\d{2}:\d{2})\t/, line) do
      [_, time_str] ->
        # Parse time format: "04:27:08" - assume today's date
        today = Date.utc_today()

        case Time.from_iso8601(time_str) do
          {:ok, time} ->
            case NaiveDateTime.new(today, time) do
              {:ok, dt} -> dt
              {:error, _} -> nil
            end

          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  defp parse_hit_quality(quality_str) do
    cond do
      String.contains?(quality_str, "Wrecks") -> :wrecking
      String.contains?(quality_str, "Smashes") -> :excellent
      String.contains?(quality_str, "Penetrates") -> :good
      String.contains?(quality_str, "Hits") -> :normal
      String.contains?(quality_str, "Glances Off") -> :glancing
      String.contains?(quality_str, "Grazes") -> :grazing
      true -> :normal
    end
  end

  defp calculate_application_percentage(quality) do
    case quality do
      :wrecking -> 100.0
      :excellent -> 90.0
      :good -> 70.0
      :normal -> 50.0
      :glancing -> 30.0
      :grazing -> 20.0
    end
  end

  # Placeholder implementations for complex analysis functions
  defp analyze_weapon_performance(_damage_events), do: %{}
  defp analyze_target_difficulty(_damage_events), do: %{}
  defp analyze_tackle_timing(_tackle_attempts, _events), do: %{}
  defp calculate_defensive_reaction_times(_defensive, _damage), do: [0]
  defp calculate_damage_before_defense(_defensive, _damage), do: 0
  defp calculate_range_discipline_score(_events), do: 50.0
  defp rate_target_prioritization(_target_stats), do: :average
  defp extract_modules_from_fitting(_fitting_data), do: []
  defp extract_used_modules_from_events(_events), do: %{}
  defp recommend_module_usage(_module, _stats), do: "Monitor usage"
  defp determine_unused_reason(_module, _events), do: "Unknown"
  defp suggest_usage_improvement(_module, _events), do: "Review tactical situation"
  defp extract_failed_action(_line), do: "Unknown action"
  defp analyze_module_usage_patterns(_events), do: %{}
  defp analyze_survivability_patterns(_events), do: %{}
  defp suggest_fitting_improvements(_events, _fitting_data), do: []
  defp rate_fitting_effectiveness(_events, _fitting_data), do: 50.0

  # Filter and summary functions (simplified versions of existing functions)
  defp filter_by_time(events, nil, nil), do: events
  # Implement time filtering
  defp filter_by_time(events, _start_time, _end_time), do: events

  defp filter_by_pilot(events, nil), do: events
  # Implement pilot filtering
  defp filter_by_pilot(events, _pilot_name), do: events

  defp generate_enhanced_summary(events, _pilot_name) do
    damage_dealt =
      events
      |> Enum.filter(&(&1.type == :damage_dealt))
      |> Enum.map(& &1.damage)
      |> Enum.sum()

    damage_received =
      events
      |> Enum.filter(&(&1.type == :damage_received))
      |> Enum.map(& &1.damage)
      |> Enum.sum()

    %{
      total_damage_dealt: damage_dealt,
      total_damage_received: damage_received,
      event_count: length(events),
      time_span: calculate_time_span(events),
      tactical_score: calculate_tactical_score(events)
    }
  end

  defp generate_tactical_recommendations(tactical_analysis, _events) do
    []
    |> maybe_add_damage_application_recommendation(tactical_analysis)
    |> maybe_add_range_management_recommendation(tactical_analysis)
    |> maybe_add_defensive_recommendation(tactical_analysis)
  end

  defp maybe_add_damage_application_recommendation(recommendations, tactical_analysis) do
    if tactical_analysis.damage_application[:average_application] &&
         tactical_analysis.damage_application.average_application < 60 do
      [
        "Consider using tracking enhancers or webs to improve hit quality (#{tactical_analysis.damage_application.average_application}% avg application)"
        | recommendations
      ]
    else
      recommendations
    end
  end

  defp maybe_add_range_management_recommendation(recommendations, tactical_analysis) do
    if tactical_analysis.range_management[:range_failures] > 5 do
      [
        "Improve range management - #{tactical_analysis.range_management.range_failures} out-of-range attempts detected"
        | recommendations
      ]
    else
      recommendations
    end
  end

  defp maybe_add_defensive_recommendation(recommendations, tactical_analysis) do
    if tactical_analysis.defensive_reactions[:average_reaction_time] > 3 do
      [
        "Activate defensive modules earlier - #{Float.round(tactical_analysis.defensive_reactions.average_reaction_time, 1)}s average reaction time"
        | recommendations
      ]
    else
      recommendations
    end
  end

  defp extract_metadata(events) do
    timestamps = events |> Enum.map(& &1.timestamp) |> Enum.filter(& &1)

    %{
      start_time: if(length(timestamps) > 0, do: Enum.min(timestamps), else: nil),
      end_time: if(length(timestamps) > 0, do: Enum.max(timestamps), else: nil),
      event_types: events |> Enum.map(& &1.type) |> Enum.uniq(),
      total_events: length(events)
    }
  end

  defp calculate_time_span(events) do
    timestamps = events |> Enum.map(& &1.timestamp) |> Enum.filter(& &1)

    case timestamps do
      [] ->
        0

      [_] ->
        0

      _ ->
        start_time = Enum.min(timestamps)
        end_time = Enum.max(timestamps)
        NaiveDateTime.diff(end_time, start_time, :second) / 60
    end
  end

  defp calculate_tactical_score(_events) do
    # Simplified tactical scoring
    75.0
  end
end
