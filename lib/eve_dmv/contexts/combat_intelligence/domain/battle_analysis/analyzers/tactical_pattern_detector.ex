defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.TacticalPatternDetector do
  @moduledoc """
  Detects and analyzes tactical patterns in battle timelines.

  Responsible for:
  - Identifying combat patterns (alpha strike, kiting, brawling)
  - Detecting key moments and turning points
  - Analyzing engagement flow and battle phases
  - Measuring focus fire effectiveness
  - Evaluating target selection strategies
  """

  require Logger

  @doc """
  Identify tactical patterns from engagement timeline.
  """
  def identify_tactical_patterns(timeline) do
    patterns = []

    # Pattern 1: Alpha strike (many kills in short time)
    patterns = patterns ++ identify_alpha_strike_pattern(timeline)

    # Pattern 2: Kiting (consistent damage over time with minimal losses)
    patterns = patterns ++ identify_kiting_pattern(timeline)

    # Pattern 3: Brawling (high kill rate on both sides)
    patterns = patterns ++ identify_brawling_pattern(timeline)

    patterns
  end

  @doc """
  Identify significant moments in the battle.
  """
  def identify_key_moments(timeline) do
    moments = []

    # Find high-value kills (top 10% by ISK value)
    moments =
      if length(timeline) > 0 do
        isk_values = Enum.map(timeline, & &1.isk_value)
        threshold = Enum.max(isk_values) * 0.9

        high_value_kills =
          timeline
          |> Enum.filter(&(&1.isk_value >= threshold))
          |> Enum.map(fn event ->
            %{
              type: :high_value_kill,
              timestamp: event.timestamp,
              isk_value: event.isk_value,
              victim: event.victim
            }
          end)

        moments ++ high_value_kills
      else
        moments
      end

    # Find first blood
    moments =
      if first_kill = List.first(timeline) do
        [
          %{
            type: :first_blood,
            timestamp: first_kill.timestamp,
            victim: first_kill.victim
          }
          | moments
        ]
      else
        moments
      end

    # Sort by timestamp
    Enum.sort_by(moments, & &1.timestamp)
  end

  @doc """
  Identify moments where battle momentum shifted.
  """
  def identify_turning_points(timeline, fleet_analysis) do
    turning_points = []

    # Analyze kill rate changes over time
    if length(timeline) >= 5 do
      # Group kills into 2-minute windows
      windows =
        timeline
        |> Enum.chunk_by(fn event ->
          div(DateTime.to_unix(event.timestamp), 120)
        end)
        |> Enum.filter(fn window -> length(window) > 0 end)

      # Calculate kill rates for each side per window
      window_stats =
        Enum.map(windows, fn window ->
          side_a_kills =
            Enum.count(window, fn event ->
              victim_side = determine_victim_side(event.victim, fleet_analysis)
              victim_side == :side_b
            end)

          side_b_kills =
            Enum.count(window, fn event ->
              victim_side = determine_victim_side(event.victim, fleet_analysis)
              victim_side == :side_a
            end)

          %{
            timestamp: List.first(window).timestamp,
            side_a_kills: side_a_kills,
            side_b_kills: side_b_kills,
            momentum: side_a_kills - side_b_kills
          }
        end)

      # Find momentum shifts
      turning_points =
        window_stats
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.filter(fn [prev, curr] ->
          # Momentum reversed
          (prev.momentum > 0 and curr.momentum < 0) or
            (prev.momentum < 0 and curr.momentum > 0)
        end)
        |> Enum.map(fn [_prev, curr] ->
          %{
            type: :momentum_shift,
            timestamp: curr.timestamp,
            new_momentum: curr.momentum
          }
        end)

      turning_points
    else
      turning_points
    end
  end

  @doc """
  Analyze the flow and phases of the engagement.
  """
  def analyze_engagement_flow(timeline) do
    phases = identify_battle_phases_detailed(timeline)
    intensity_changes = identify_intensity_changes(timeline)

    %{
      phases: phases,
      intensity_changes: intensity_changes
    }
  end

  @doc """
  Analyze how well fleets focused their damage.
  """
  def analyze_focus_fire(timeline) do
    if length(timeline) < 2 do
      %{
        effectiveness: 0.0,
        coordination_score: 0.0
      }
    else
      # Group kills by 30-second windows
      windows =
        timeline
        |> Enum.chunk_by(fn event ->
          div(DateTime.to_unix(event.timestamp), 30)
        end)
        |> Enum.filter(fn window -> length(window) > 1 end)

      if Enum.empty?(windows) do
        %{
          effectiveness: 0.0,
          coordination_score: 0.0
        }
      else
        # Calculate focus fire metrics for each window
        window_metrics = Enum.map(windows, &calculate_window_metrics/1)

        # Weight by number of kills in each window
        total_kills = Enum.sum(Enum.map(window_metrics, & &1.kills))

        weighted_focus =
          window_metrics
          |> Enum.map(&(&1.focus_score * &1.kills))
          |> Enum.sum()
          |> Kernel./(total_kills)

        weighted_coordination =
          window_metrics
          |> Enum.map(&(&1.time_score * &1.kills))
          |> Enum.sum()
          |> Kernel./(total_kills)

        %{
          effectiveness: Float.round(weighted_focus, 3),
          coordination_score: Float.round(weighted_coordination, 3)
        }
      end
    end
  end

  @doc """
  Analyze target prioritization effectiveness.
  """
  def analyze_target_selection(timeline, _fleet_analysis) do
    if Enum.empty?(timeline) do
      %{
        priority_targets_hit: 0.0,
        target_switching_rate: 0.0
      }
    else
      # Identify priority targets (logistics, fleet commanders, high-value ships)
      priority_kills =
        timeline
        |> Enum.filter(fn event ->
          ship_class = classify_ship(event.victim.ship_type_id)
          # 1B+ ISK
          ship_class in [:logistics, :strategic_cruiser, :capital] or
            event.isk_value > 1_000_000_000
        end)

      priority_ratio =
        if length(timeline) > 0 do
          Float.round(length(priority_kills) / length(timeline), 3)
        else
          0.0
        end

      # Calculate target switching rate
      target_switches =
        timeline
        |> Enum.map(& &1.victim.character_id)
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.count(fn [prev, curr] -> prev != curr end)

      switching_rate =
        if length(timeline) > 1 do
          Float.round(target_switches / (length(timeline) - 1), 3)
        else
          0.0
        end

      %{
        priority_targets_hit: priority_ratio,
        target_switching_rate: switching_rate
      }
    end
  end

  # Private pattern detection functions

  defp identify_alpha_strike_pattern(timeline) do
    # Group kills by 30-second windows
    windows =
      Enum.chunk_by(timeline, fn event ->
        div(DateTime.to_unix(event.timestamp), 30)
      end)

    # Find windows with high kill concentration
    alpha_strikes =
      windows
      |> Enum.filter(fn window -> length(window) >= 3 end)
      |> Enum.map(fn window ->
        %{
          pattern: :alpha_strike,
          timestamp: List.first(window).timestamp,
          kills: length(window),
          duration_seconds: 30
        }
      end)

    alpha_strikes
  end

  defp identify_kiting_pattern(timeline) do
    # Kiting pattern characteristics:
    # - Consistent kills over extended time with minimal losses on one side
    # - High time gaps between reciprocal kills
    # - One side maintains range advantage

    if length(timeline) < 5 do
      []
    else
      # Analyze kill distribution by side over time
      # 2-minute windows
      time_windows = group_timeline_by_windows(timeline, 120)

      kiting_patterns =
        time_windows
        # Look at 3-window sequences
        |> Enum.chunk_every(3, 1, :discard)
        |> Enum.filter(&detect_kiting_sequence/1)
        |> Enum.map(fn [first_window, _mid_window, last_window] ->
          %{
            pattern: :kiting,
            start_timestamp: List.first(first_window).timestamp,
            end_timestamp: List.last(last_window).timestamp,
            duration_seconds:
              DateTime.diff(
                List.last(last_window).timestamp,
                List.first(first_window).timestamp
              ),
            characteristic: "Sustained range advantage with minimal reciprocal damage"
          }
        end)

      kiting_patterns
    end
  end

  defp identify_brawling_pattern(timeline) do
    # Brawling pattern characteristics:
    # - High reciprocal kill rate (both sides taking losses)
    # - Short time intervals between kills
    # - High concentration of kills in short periods

    if length(timeline) < 4 do
      []
    else
      # Group kills into 60-second windows for brawl detection
      # 1-minute windows
      time_windows = group_timeline_by_windows(timeline, 60)

      brawling_patterns =
        time_windows
        |> Enum.filter(&detect_brawling_window/1)
        |> Enum.chunk_by(fn window ->
          # Group consecutive brawling windows
          first_kill = List.first(window)
          # 2-minute chunks
          div(DateTime.to_unix(first_kill.timestamp), 120)
        end)
        # At least 2 consecutive windows
        |> Enum.filter(fn window_group -> length(window_group) >= 2 end)
        |> Enum.map(fn window_group ->
          first_window = List.first(window_group)
          last_window = List.last(window_group)

          all_kills = Enum.flat_map(window_group, & &1)

          %{
            pattern: :brawling,
            start_timestamp: List.first(first_window).timestamp,
            end_timestamp: List.last(last_window).timestamp,
            duration_seconds:
              DateTime.diff(
                List.last(last_window).timestamp,
                List.first(first_window).timestamp
              ),
            intensity: length(all_kills) / max(1, length(window_group)),
            characteristic: "High intensity close-range combat with reciprocal losses"
          }
        end)

      brawling_patterns
    end
  end

  # Private helper functions

  defp group_timeline_by_windows(timeline, window_seconds) do
    timeline
    |> Enum.group_by(fn event ->
      div(DateTime.to_unix(event.timestamp), window_seconds)
    end)
    |> Map.values()
    |> Enum.filter(fn window -> length(window) > 0 end)
    |> Enum.sort_by(fn window -> List.first(window).timestamp end, DateTime)
  end

  defp detect_kiting_sequence([window1, window2, window3]) do
    # Calculate side kill ratios for each window
    side_ratios = Enum.map([window1, window2, window3], &calculate_window_side_ratio/1)

    # Check for consistent one-sided advantage (kiting indicator)
    consistent_advantage =
      Enum.all?(side_ratios, fn ratio ->
        # Strong advantage to one side
        ratio > 2.0 or ratio < 0.5
      end)

    # Check that the advantage is in the same direction
    same_direction =
      Enum.all?(side_ratios, &(&1 > 1.0)) or
        Enum.all?(side_ratios, &(&1 < 1.0))

    consistent_advantage and same_direction
  end

  defp detect_brawling_window(window) do
    if length(window) < 3 do
      false
    else
      # High kill concentration and reciprocal damage
      # kills per second in this minute
      kill_rate = length(window) / 60
      side_ratio = calculate_window_side_ratio(window)

      # Brawling: high activity and balanced kills (not too one-sided)
      # More than 3 kills per minute
      high_intensity = kill_rate > 0.05
      # Not too one-sided
      balanced_fight = side_ratio >= 0.4 and side_ratio <= 2.5

      high_intensity and balanced_fight
    end
  end

  defp calculate_window_metrics(window) do
    # Count unique targets
    unique_targets =
      window
      |> Enum.map(& &1.victim.character_id)
      |> Enum.uniq()
      |> length()

    # Perfect focus fire = 1 target per window
    focus_score = 1.0 / unique_targets

    # Time spread - how close together were the kills
    time_score =
      if length(window) > 1 do
        time_spread =
          DateTime.diff(
            List.last(window).timestamp,
            List.first(window).timestamp
          )

        # Normalize to 0-1 where <10s = 1.0
        max(0, 1.0 - time_spread / 30.0)
      else
        1.0
      end

    %{
      focus_score: focus_score,
      time_score: time_score,
      kills: length(window)
    }
  end

  defp calculate_window_side_ratio(window) do
    # Simplified side determination based on corporation grouping
    # Group by corporation to approximate sides
    corp_kills =
      window
      |> Enum.group_by(fn event -> event.victim.corporation_id end)
      |> Map.values()
      |> Enum.map(&length/1)
      |> Enum.sort(:desc)

    case corp_kills do
      [side_a_losses, side_b_losses | _] ->
        if side_b_losses > 0 do
          side_a_losses / side_b_losses
        else
          # One-sided if no losses on other side
          side_a_losses
        end

      [side_a_losses] ->
        # Completely one-sided
        side_a_losses

      [] ->
        # No kills
        1.0
    end
  end

  defp determine_victim_side(victim, fleet_analysis) do
    # Handle different fleet analysis structures
    side_a_corps = get_side_corporations(fleet_analysis, :side_a)
    side_b_corps = get_side_corporations(fleet_analysis, :side_b)

    cond do
      victim.corporation_id in side_a_corps -> :side_a
      victim.corporation_id in side_b_corps -> :side_b
      true -> :unknown
    end
  end

  defp identify_battle_phases_detailed(timeline) do
    # Identify distinct phases based on kill clustering
    if length(timeline) < 3 do
      []
    else
      # Find gaps of more than 5 minutes between kills
      phases =
        timeline
        |> Enum.chunk_while(
          [],
          &chunk_events_by_time_gap/2,
          &finalize_phase_chunk/1
        )
        |> Enum.reject(&Enum.empty?/1)
        |> Enum.with_index(1)
        |> Enum.map(fn {phase_events, index} ->
          %{
            phase_number: index,
            start_time: List.first(phase_events).timestamp,
            end_time: List.last(phase_events).timestamp,
            duration_seconds:
              DateTime.diff(
                List.last(phase_events).timestamp,
                List.first(phase_events).timestamp
              ),
            kills: length(phase_events),
            intensity:
              length(phase_events) /
                max(
                  DateTime.diff(
                    List.last(phase_events).timestamp,
                    List.first(phase_events).timestamp
                  ) / 60,
                  1
                )
          }
        end)

      phases
    end
  end

  defp chunk_events_by_time_gap(event, acc) do
    case acc do
      [] ->
        {:cont, [event]}

      _ ->
        last_event = List.first(acc)
        gap_seconds = DateTime.diff(event.timestamp, last_event.timestamp)

        # 5 minute gap
        if gap_seconds > 300 do
          {:cont, Enum.reverse(acc), [event]}
        else
          {:cont, [event | acc]}
        end
    end
  end

  defp finalize_phase_chunk(acc) do
    case acc do
      [] -> {:cont, []}
      acc -> {:cont, Enum.reverse(acc), []}
    end
  end

  defp identify_intensity_changes(timeline) do
    # Calculate rolling kill rate and find significant changes
    if length(timeline) < 5 do
      []
    else
      # Calculate kills per minute in 3-minute windows
      intensities =
        timeline
        |> Enum.chunk_every(3, 1, :discard)
        |> Enum.map(fn window ->
          duration_minutes =
            DateTime.diff(
              List.last(window).timestamp,
              List.first(window).timestamp
            ) / 60

          %{
            # Middle of window
            timestamp: Enum.at(window, 1).timestamp,
            kills_per_minute:
              if(duration_minutes > 0, do: length(window) / duration_minutes, else: 0)
          }
        end)

      # Find significant intensity changes (>50% change)
      intensity_changes =
        intensities
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.filter(fn [prev, curr] ->
          change_ratio =
            if prev.kills_per_minute > 0 do
              abs(curr.kills_per_minute - prev.kills_per_minute) / prev.kills_per_minute
            else
              1.0
            end

          change_ratio > 0.5
        end)
        |> Enum.map(fn [prev, curr] ->
          %{
            timestamp: curr.timestamp,
            previous_intensity: Float.round(prev.kills_per_minute, 2),
            new_intensity: Float.round(curr.kills_per_minute, 2),
            change_type:
              if(curr.kills_per_minute > prev.kills_per_minute,
                do: :escalation,
                else: :deescalation
              )
          }
        end)

      intensity_changes
    end
  end

  defp classify_ship(ship_type_id) do
    # Classify ship based on type ID ranges (simplified EVE ship classification)
    cond do
      # Frigates
      ship_type_id in [582, 583, 584, 585, 586, 587, 588, 589] -> :frigate
      # Destroyers
      ship_type_id in [16_236, 16_238, 16_240, 16_242] -> :destroyer
      # Cruisers
      ship_type_id in [620, 621, 622, 623, 624, 625, 626, 627] -> :cruiser
      # Battlecruisers
      ship_type_id in [16_227, 16_229, 16_231, 16_233] -> :battlecruiser
      # Battleships
      ship_type_id in [638, 639, 640, 641, 642, 643, 644, 645] -> :battleship
      # Strategic Cruisers (T3C)
      ship_type_id in [29_984, 29_986, 29_988, 29_990] -> :strategic_cruiser
      # Logistics Cruisers
      ship_type_id in [11_987, 11_989, 12_015, 12_019] -> :logistics
      # Recon Ships
      ship_type_id in [11_957, 11_958, 11_965, 11_969] -> :recon
      # Heavy Assault Cruisers
      ship_type_id in [12_003, 12_005, 12_009, 12_011] -> :heavy_assault_cruiser
      # Capital Ships
      ship_type_id in [19_720, 19_722, 19_724, 19_726] -> :capital
      # Default
      true -> :unknown
    end
  end

  defp get_side_corporations(fleet_analysis, side_key) do
    case get_in(fleet_analysis, [side_key]) do
      nil -> []
      side_data -> get_side_corporations_from_data(side_data)
    end
  end

  defp get_side_corporations_from_data(side_data) do
    cond do
      # If side has a corporations field with a map
      is_map(side_data) && Map.has_key?(side_data, :corporations) ->
        Map.keys(side_data.corporations)

      # If side has a corporations field as atom key
      is_map(side_data) && Map.has_key?(side_data, "corporations") ->
        Map.keys(side_data["corporations"])

      # If side data is directly a map of corporations
      is_map(side_data) ->
        Map.keys(side_data)

      # If side data is a list of corporation IDs
      is_list(side_data) ->
        side_data

      # Default to empty list
      true ->
        []
    end
  end
end
