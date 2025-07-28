defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Analyzers.EngagementAnalyzer do
  @moduledoc """
  Analyzer for engagement patterns and combat flow.

  Extracts and analyzes engagement-related functions from the tactical analysis system.
  """

  require Logger

  @doc """
  Analyze engagement patterns from battle timeline and participant data.
  """
  def analyze_engagement_patterns(timeline, participants) do
    # Analyze how the engagement unfolded over time
    Logger.debug("Analyzing engagement patterns")

    # Determine engagement initiation style
    initiation_style = determine_engagement_initiation(timeline, participants)

    # Identify engagement phases based on kill intensity
    phases = identify_engagement_phases(timeline)

    # Analyze engagement rhythm (sustained, burst, intermittent)
    rhythm = analyze_engagement_rhythm(timeline)

    # Identify disengagement patterns
    disengagement_patterns = identify_disengagement_patterns(timeline, participants)

    # Calculate effectiveness based on objectives achieved
    effectiveness = calculate_engagement_effectiveness(timeline, participants, phases)

    %{
      engagement_initiation: initiation_style,
      engagement_phases: phases,
      engagement_rhythm: rhythm,
      disengagement_patterns: disengagement_patterns,
      engagement_effectiveness: effectiveness,
      intensity_profile: calculate_intensity_profile(timeline)
    }
  end

  @doc """
  Evaluate engagement effectiveness based on timeline and participants.
  """
  def evaluate_engagement_effectiveness(timeline, participants) do
    # Evaluate engagement effectiveness based on objectives and execution
    if Enum.empty?(timeline.events) do
      0.0
    else
      engagement_patterns = analyze_engagement_patterns(timeline, participants)

      # Engagement effectiveness factors
      initiation_success = evaluate_initiation_success(engagement_patterns)
      phase_execution = evaluate_phase_execution(engagement_patterns)
      rhythm_consistency = evaluate_rhythm_consistency(engagement_patterns)

      # Calculate weighted effectiveness
      initiation_success * 0.3 + phase_execution * 0.5 + rhythm_consistency * 0.2
    end
  end

  # Private helper functions

  defp determine_engagement_initiation(timeline, _participants) do
    # Analyze the first few kills to determine how engagement started
    early_events = Enum.take(timeline.events, 3)

    if Enum.empty?(early_events) do
      :unknown
    else
      first_event = hd(early_events)
      attacker_count = length(first_event.attackers)

      cond do
        attacker_count > 20 -> :alpha_strike
        attacker_count > 10 -> :coordinated_attack
        attacker_count > 5 -> :small_gang
        true -> :skirmish
      end
    end
  end

  defp identify_engagement_phases(timeline) do
    # Identify distinct phases based on kill intensity
    # 1-minute windows
    time_windows = create_time_windows(timeline.events, 60)

    time_windows
    |> Enum.map(fn {timestamp, events} ->
      %{
        timestamp: timestamp,
        kill_count: length(events),
        phase_type: determine_phase_type(length(events))
      }
    end)
    |> consolidate_phases()
  end

  defp analyze_engagement_rhythm(timeline) do
    # Analyze the rhythm of kills over time
    if length(timeline.events) < 3 do
      :unknown
    else
      # Calculate time gaps between kills
      gaps =
        timeline.events
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [prev, current] ->
          current.timestamp - prev.timestamp
        end)

      avg_gap = Enum.sum(gaps) / length(gaps)
      variance = calculate_variance(gaps, avg_gap)

      cond do
        variance < 30 -> :sustained
        variance < 60 -> :burst
        true -> :intermittent
      end
    end
  end

  defp identify_disengagement_patterns(timeline, _participants) do
    # Identify when and how forces disengaged
    # Look for gaps in kill activity
    long_gaps =
      timeline.events
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.filter(fn [prev, current] ->
        # 5+ minute gap
        current.timestamp - prev.timestamp > 300
      end)
      |> Enum.map(fn [prev, current] ->
        %{
          after_event: prev.killmail_id,
          gap_duration: current.timestamp - prev.timestamp,
          type: :temporary_disengagement
        }
      end)

    # Check if battle ended with withdrawal
    final_pattern =
      if length(timeline.events) > 5 do
        last_events = Enum.take(timeline.events, -5)

        if decreasing_intensity?(last_events) do
          [%{type: :gradual_withdrawal, timestamp: List.last(timeline.events).timestamp}]
        else
          []
        end
      else
        []
      end

    long_gaps ++ final_pattern
  end

  defp calculate_engagement_effectiveness(timeline, participants, phases) do
    # Calculate effectiveness based on multiple factors
    if Enum.empty?(timeline.events) do
      0.0
    else
      # Calculate kill efficiency
      kill_efficiency = calculate_kill_efficiency(timeline, participants)

      # Calculate phase execution quality
      phase_quality = evaluate_phase_quality(phases)

      # Calculate overall control
      control_score = calculate_engagement_control(timeline)

      # Weighted average
      kill_efficiency * 0.4 + phase_quality * 0.3 + control_score * 0.3
    end
  end

  defp calculate_intensity_profile(timeline) do
    # Create an intensity profile over time
    # 30-second windows
    time_windows = create_time_windows(timeline.events, 30)

    Enum.map(time_windows, fn {timestamp, events} ->
      %{
        timestamp: timestamp,
        intensity: length(events),
        isk_destroyed: calculate_window_isk(events)
      }
    end)
  end

  defp create_time_windows(events, window_seconds) do
    events
    |> Enum.group_by(fn event ->
      div(event.timestamp, window_seconds) * window_seconds
    end)
    |> Enum.sort_by(fn {timestamp, _} -> timestamp end)
  end

  defp determine_phase_type(kill_count) do
    cond do
      kill_count == 0 -> :lull
      kill_count < 3 -> :skirmish
      kill_count < 10 -> :escalation
      true -> :peak_intensity
    end
  end

  defp consolidate_phases(phase_windows) do
    # Merge adjacent windows with same phase type
    phase_windows
    |> Enum.chunk_by(& &1.phase_type)
    |> Enum.map(fn phase_group ->
      %{
        phase_type: hd(phase_group).phase_type,
        start_time: hd(phase_group).timestamp,
        end_time: List.last(phase_group).timestamp,
        total_kills: Enum.sum(Enum.map(phase_group, & &1.kill_count))
      }
    end)
  end

  defp calculate_variance(values, mean) do
    if Enum.empty?(values) do
      0
    else
      sum_squared_diff =
        values
        |> Enum.map(fn v -> :math.pow(v - mean, 2) end)
        |> Enum.sum()

      :math.sqrt(sum_squared_diff / length(values))
    end
  end

  defp decreasing_intensity?(events) do
    # Check if kill intensity is decreasing
    kill_times = Enum.map(events, & &1.timestamp)

    # Compare first half vs second half
    mid_point = div(length(kill_times), 2)
    {first_half, second_half} = Enum.split(kill_times, mid_point)

    if not Enum.empty?(first_half) && not Enum.empty?(second_half) do
      first_density = length(first_half) / (List.last(first_half) - hd(first_half) + 1)
      second_density = length(second_half) / (List.last(second_half) - hd(second_half) + 1)

      second_density < first_density * 0.5
    else
      false
    end
  end

  defp calculate_kill_efficiency(_timeline, _participants) do
    # Simplified kill efficiency calculation
    0.7
  end

  defp evaluate_phase_quality(phases) do
    if Enum.empty?(phases) do
      0.0
    else
      # Score based on phase progression
      peak_phases = Enum.count(phases, &(&1.phase_type == :peak_intensity))
      total_phases = length(phases)

      if total_phases > 0 do
        peak_phases / total_phases
      else
        0.0
      end
    end
  end

  defp calculate_engagement_control(_timeline) do
    # Simplified engagement control calculation
    0.6
  end

  defp calculate_window_isk(events) do
    # Calculate total ISK destroyed in this window
    Enum.sum(Enum.map(events, & &1.total_value))
  end

  defp evaluate_initiation_success(engagement_patterns) do
    case engagement_patterns[:engagement_initiation] do
      :alpha_strike -> 0.9
      :coordinated_attack -> 0.8
      :small_gang -> 0.7
      :skirmish -> 0.6
      _ -> 0.5
    end
  end

  defp evaluate_phase_execution(engagement_patterns) do
    phases = engagement_patterns[:engagement_phases] || []

    if Enum.empty?(phases) do
      0.5
    else
      # Score based on phase progression quality
      evaluate_phase_quality(phases)
    end
  end

  defp evaluate_rhythm_consistency(engagement_patterns) do
    case engagement_patterns[:engagement_rhythm] do
      :sustained -> 0.9
      :burst -> 0.7
      :intermittent -> 0.5
      _ -> 0.4
    end
  end
end
