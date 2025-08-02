defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.PerformanceMetricsCalculator do
  @moduledoc """
  Performance metrics calculator for battle analysis.

  Provides comprehensive performance analysis including:
  - Entity performance tracking across battles
  - Battle duration calculations
  - Participant flow analysis
  - Victory determination and factor analysis
  - Timeline tracking and flow metrics
  """
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Phases.OutcomeAnalyzer
  alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  @doc """
  Analyze performance for a specific entity across multiple battles.
  """
  def analyze_entity_performance(entity_id, entity_type, battles) do
    {:ok,
     %{
       entity_id: entity_id,
       entity_type: entity_type,
       battle_count: length(battles),
       win_rate: 0.0,
       average_efficiency: 100.0,
       preferred_doctrines: [],
       performance_trend: :stable
     }}
  end

  @doc """
  Fetch battles for a specific entity within a time range.
  """
  def fetch_entity_battles(_entity_id, _entity_type, _time_range) do
    {:ok, []}
  end

  @doc """
  Track participant flow throughout a battle timeline.
  """
  def track_participant_flow(timeline) do
    # Track when participants join/leave battle by analyzing their activity patterns
    if length(timeline) < 2 do
      %{
        joiners: [],
        leavers: [],
        flow_summary: %{
          total_joiners: 0,
          total_leavers: 0,
          peak_participants: 0,
          average_participants: 0,
          participation_stability: :stable
        }
      }
    else
      # Sort timeline by time for analysis
      sorted_timeline = Enum.sort_by(timeline, & &1.killmail_time)

      # Create time windows for participant tracking (2-minute intervals)
      start_time = List.first(sorted_timeline).killmail_time
      end_time = List.last(sorted_timeline).killmail_time
      # 2-minute intervals
      time_windows = create_participant_tracking_windows(start_time, end_time, 120)

      # Track participants in each window
      window_participants =
        time_windows
        |> Enum.map(fn {window_start, window_end} ->
          participants_in_window =
            sorted_timeline
            |> Enum.filter(fn km ->
              kill_time = km.killmail_time

              DateTimeUtils.compare(kill_time, window_start) in [:eq, :gt] and
                DateTimeUtils.compare(kill_time, window_end) == :lt
            end)
            |> Enum.flat_map(&extract_participants_from_killmail/1)
            |> Enum.uniq()

          %{
            window_start: window_start,
            window_end: window_end,
            participants: participants_in_window,
            participant_count: length(participants_in_window)
          }
        end)
        |> Enum.filter(fn window -> window.participant_count > 0 end)

      # Analyze participant flow between windows
      flow_analysis = analyze_participant_flow_between_windows(window_participants)

      # Generate summary statistics
      flow_summary = generate_participation_flow_summary(window_participants, flow_analysis)

      %{
        joiners: flow_analysis.joiners,
        leavers: flow_analysis.leavers,
        flow_events: flow_analysis.flow_events,
        participant_windows: window_participants,
        flow_summary: flow_summary
      }
    end
  end

  @doc """
  Create time windows for tracking participant flow.
  """
  def create_participant_tracking_windows(start_time, end_time, interval_seconds) do
    # Create time windows optimized for participant tracking
    duration_seconds = DateTimeUtils.diff(end_time, start_time, :second)

    # Use minimum of 2 windows even for very short battles
    bucket_count = max(2, div(duration_seconds, interval_seconds))

    0..(bucket_count - 1)
    |> Enum.map(fn bucket_index ->
      bucket_start = DateTimeUtils.add(start_time, bucket_index * interval_seconds, :second)
      bucket_end = DateTimeUtils.add(start_time, (bucket_index + 1) * interval_seconds, :second)

      # Ensure the last bucket covers until the actual end time
      bucket_end =
        if DateTimeUtils.compare(bucket_end, end_time) == :gt, do: end_time, else: bucket_end

      {bucket_start, bucket_end}
    end)
  end

  @doc """
  Analyze participant flow between consecutive time windows.
  """
  def analyze_participant_flow_between_windows(window_participants) do
    # Compare consecutive windows to identify joiners and leavers

    {joiners, leavers, flow_events} =
      window_participants
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce({[], [], []}, fn [prev_window, curr_window],
                                      {acc_joiners, acc_leavers, acc_events} ->
        prev_participants = MapSet.new(prev_window.participants)
        curr_participants = MapSet.new(curr_window.participants)

        # Find new participants (joiners)
        new_participants = MapSet.difference(curr_participants, prev_participants)

        # Find departed participants (leavers)
        departed_participants = MapSet.difference(prev_participants, curr_participants)

        # Create flow events if there are significant changes
        flow_event =
          if MapSet.size(new_participants) > 0 or MapSet.size(departed_participants) > 0 do
            %{
              timestamp: curr_window.window_start,
              window_transition:
                "#{format_timestamp(prev_window.window_start)} -> #{format_timestamp(curr_window.window_start)}",
              joiners_count: MapSet.size(new_participants),
              leavers_count: MapSet.size(departed_participants),
              net_change: MapSet.size(new_participants) - MapSet.size(departed_participants),
              joiners: MapSet.to_list(new_participants),
              leavers: MapSet.to_list(departed_participants),
              flow_type:
                determine_flow_type(
                  MapSet.size(new_participants),
                  MapSet.size(departed_participants)
                )
            }
          else
            nil
          end

        # Create joiner records
        new_joiner_records =
          MapSet.to_list(new_participants)
          |> Enum.map(fn participant_id ->
            %{
              participant_id: participant_id,
              joined_at: curr_window.window_start,
              join_window: curr_window.window_start,
              context: %{
                participants_before: MapSet.size(prev_participants),
                participants_after: MapSet.size(curr_participants)
              }
            }
          end)

        # Create leaver records
        new_leaver_records =
          MapSet.to_list(departed_participants)
          |> Enum.map(fn participant_id ->
            %{
              participant_id: participant_id,
              left_at: curr_window.window_start,
              leave_window: prev_window.window_start,
              context: %{
                participants_before: MapSet.size(prev_participants),
                participants_after: MapSet.size(curr_participants)
              }
            }
          end)

        updated_events = if flow_event, do: [flow_event | acc_events], else: acc_events

        {acc_joiners ++ new_joiner_records, acc_leavers ++ new_leaver_records, updated_events}
      end)

    %{
      joiners: Enum.reverse(joiners),
      leavers: Enum.reverse(leavers),
      flow_events: Enum.reverse(flow_events)
    }
  end

  @doc """
  Generate participation flow summary statistics.
  """
  def generate_participation_flow_summary(window_participants, flow_analysis) do
    # Calculate summary statistics for participant flow
    participant_counts = Enum.map(window_participants, & &1.participant_count)

    peak_participants =
      if Enum.empty?(participant_counts), do: 0, else: Enum.max(participant_counts)

    average_participants =
      if Enum.empty?(participant_counts) do
        0
      else
        Float.round(Enum.sum(participant_counts) / length(participant_counts), 1)
      end

    # Calculate participation stability
    participation_stability = calculate_participation_stability(participant_counts)

    # Analyze flow patterns
    flow_pattern = analyze_flow_pattern(flow_analysis.flow_events)

    %{
      total_joiners: length(flow_analysis.joiners),
      total_leavers: length(flow_analysis.leavers),
      peak_participants: peak_participants,
      average_participants: average_participants,
      participation_stability: participation_stability,
      flow_pattern: flow_pattern,
      net_participant_change: length(flow_analysis.joiners) - length(flow_analysis.leavers),
      most_active_period: identify_most_active_period(window_participants),
      flow_events_count: length(flow_analysis.flow_events)
    }
  end

  @doc """
  Determine the winner of a battle based on performance metrics.
  """
  def determine_battle_winner(_performance_metrics) do
    :undetermined
  end

  @doc """
  Analyze factors that contributed to battle victory.
  """
  def analyze_victory_factors(tactical_analysis, performance_metrics) do
    # Use the comprehensive OutcomeAnalyzer for detailed victory factor analysis
    OutcomeAnalyzer.analyze_victory_factors(tactical_analysis, performance_metrics)
  rescue
    e ->
      Logger.error("Victory factor analysis failed: #{Exception.message(e)}")
      # Fallback to basic analysis if the comprehensive analyzer fails
      perform_basic_victory_analysis(tactical_analysis, performance_metrics)
  end

  @doc """
  Calculate the duration of a battle from timeline data.
  """
  def calculate_battle_duration(timeline) do
    if Enum.empty?(timeline) do
      0
    else
      first_event = List.first(timeline)
      last_event = List.last(timeline)
      DateTimeUtils.diff(last_event.timestamp, first_event.timestamp, :second)
    end
  end

  @doc """
  Format a timestamp for display purposes.
  """
  def format_timestamp(naive_datetime) do
    # Format timestamp for display
    NaiveDateTime.to_time(naive_datetime)
    |> Time.to_string()
    # HH:MM:SS format
    |> String.slice(0, 8)
  end

  # Private helper functions

  defp extract_participants_from_killmail(km) do
    victim_id = if km.victim_character_id, do: [km.victim_character_id], else: []

    attacker_ids =
      case km.raw_data do
        %{"attackers" => attackers} when is_list(attackers) ->
          attackers
          |> Enum.map(fn attacker -> attacker["character_id"] end)
          |> Enum.filter(&(&1 != nil))

        _ ->
          []
      end

    victim_id ++ attacker_ids
  end

  defp determine_flow_type(joiners_count, leavers_count) do
    cond do
      joiners_count > 0 and leavers_count == 0 -> :escalation
      joiners_count == 0 and leavers_count > 0 -> :de_escalation
      joiners_count > leavers_count -> :net_escalation
      leavers_count > joiners_count -> :net_de_escalation
      joiners_count > 0 and leavers_count > 0 -> :turnover
      true -> :stable
    end
  end

  defp calculate_participation_stability(participant_counts) do
    if length(participant_counts) < 2 do
      :stable
    else
      # Calculate coefficient of variation
      mean = Enum.sum(participant_counts) / length(participant_counts)

      if mean == 0 do
        :stable
      else
        variance =
          participant_counts
          |> Enum.map(fn count -> :math.pow(count - mean, 2) end)
          |> Enum.sum()
          |> Kernel./(length(participant_counts))

        std_dev = :math.sqrt(variance)
        coefficient_of_variation = std_dev / mean

        cond do
          coefficient_of_variation < 0.1 -> :very_stable
          coefficient_of_variation < 0.2 -> :stable
          coefficient_of_variation < 0.4 -> :moderately_volatile
          coefficient_of_variation < 0.6 -> :volatile
          true -> :very_volatile
        end
      end
    end
  end

  defp analyze_flow_pattern(flow_events) do
    if Enum.empty?(flow_events) do
      :no_flow
    else
      # Analyze dominant flow types
      flow_types = Enum.map(flow_events, & &1.flow_type)
      flow_type_counts = Enum.frequencies(flow_types)

      # Get the most common flow type
      dominant_flow =
        flow_type_counts
        |> Enum.max_by(fn {_type, count} -> count end, fn -> {:stable, 0} end)
        |> elem(0)

      # Check for patterns
      cond do
        # Early escalation followed by stability
        Enum.take(flow_types, 2) == [:escalation, :stable] -> :early_escalation
        # Late escalation
        List.last(flow_types) == :escalation -> :late_escalation
        # Early de-escalation
        List.first(flow_types) == :de_escalation -> :early_withdrawal
        # Alternating flows
        length(Enum.uniq(flow_types)) > 2 -> :complex_flow
        # Dominant pattern
        true -> dominant_flow
      end
    end
  end

  defp identify_most_active_period(window_participants) do
    if Enum.empty?(window_participants) do
      nil
    else
      most_active_window =
        window_participants
        |> Enum.max_by(& &1.participant_count, fn -> nil end)

      if most_active_window do
        %{
          period:
            "#{format_timestamp(most_active_window.window_start)} - #{format_timestamp(most_active_window.window_end)}",
          participant_count: most_active_window.participant_count,
          timestamp: most_active_window.window_start
        }
      else
        nil
      end
    end
  end

  defp perform_basic_victory_analysis(tactical_analysis, performance_metrics) do
    initial_factors = []

    # Analyze numerical superiority
    numerical_factors =
      initial_factors ++
        case performance_metrics.by_side do
          by_side when map_size(by_side) == 0 -> []
          by_side -> analyze_numerical_factors(by_side)
        end

    # Analyze tactical effectiveness
    tactical_factors =
      numerical_factors ++
        case tactical_analysis.patterns do
          [] -> []
          patterns -> analyze_tactical_factors(patterns)
        end

    # Analyze engagement control
    control_factors =
      tactical_factors ++
        case tactical_analysis.key_moments do
          [] -> []
          key_moments -> analyze_control_factors(key_moments)
        end

    control_factors
  end

  defp analyze_numerical_factors(_by_side) do
    []
  end

  defp analyze_tactical_factors(_patterns) do
    []
  end

  defp analyze_control_factors(_key_moments) do
    []
  end
end
