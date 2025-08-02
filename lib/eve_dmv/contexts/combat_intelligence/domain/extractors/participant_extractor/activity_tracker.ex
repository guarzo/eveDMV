defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Extractors.ParticipantExtractor.ActivityTracker do
  @moduledoc """

  Tracks participant activity patterns and engagement timelines.

  Analyzes when and how participants engage in combat, their activity
  patterns, and contribution patterns over time.
  """

    alias EveDmv.Core.Utils.DateTimeUtils

  require Logger

  @doc """
  Track participant activity throughout a battle.
  """
  def track_participant_activity(participants, killmails) do
    Logger.debug("Tracking participant activity for #{length(participants)} participants")

    # Build comprehensive activity profiles for each participant
    activity_profiles =
      participants
      |> Enum.map(fn participant ->
        character_id = Map.get(participant, :character_id)

        profile = %{
          character_id: character_id,
          character_name: Map.get(participant, :character_name),
          kills: count_participant_kills(participant, killmails),
          deaths: count_participant_deaths(participant, killmails),
          damage_dealt: calculate_damage_dealt(participant, killmails),
          damage_received: calculate_damage_received(participant, killmails),
          activity_timeline: build_activity_timeline(participant, killmails),
          contribution_score: calculate_contribution_score(participant, killmails),
          engagement_pattern: analyze_engagement_pattern(participant, killmails)
        }

        profile
      end)

    # Analyze fleet-wide activity patterns
    fleet_timeline = build_fleet_timeline(activity_profiles, killmails)
    activity_summary = summarize_activity_patterns(activity_profiles)
    engagement_phases = identify_engagement_phases(fleet_timeline)

    %{
      participant_profiles: activity_profiles,
      fleet_timeline: fleet_timeline,
      activity_summary: activity_summary,
      engagement_phases: engagement_phases,
      metrics: %{
        total_participants: length(participants),
        active_participants: count_active_participants(activity_profiles),
        peak_activity_time: identify_peak_activity_time(fleet_timeline),
        engagement_duration: calculate_total_engagement_duration(fleet_timeline)
      }
    }
  end

  @doc """
  Count kills for a specific participant.
  """
  def count_participant_kills(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      0
    else
      Enum.count(killmails, fn killmail ->
        attackers = Map.get(killmail, :attackers, [])

        Enum.any?(attackers, fn attacker ->
          Map.get(attacker, :character_id) == character_id
        end)
      end)
    end
  end

  @doc """
  Count deaths for a specific participant.
  """
  def count_participant_deaths(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      0
    else
      Enum.count(killmails, fn killmail ->
        victim = Map.get(killmail, :victim, %{})
        Map.get(victim, :character_id) == character_id
      end)
    end
  end

  @doc """
  Calculate total damage dealt by a participant.
  """
  def calculate_damage_dealt(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      0
    else
      killmails
      |> Enum.flat_map(fn killmail ->
        attackers = Map.get(killmail, :attackers, [])

        Enum.filter(attackers, fn attacker ->
          Map.get(attacker, :character_id) == character_id
        end)
      end)
      |> Enum.map(&Map.get(&1, :damage_done, 0))
      |> Enum.sum()
    end
  end

  @doc """
  Calculate damage received by a participant.
  """
  def calculate_damage_received(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      0
    else
      killmails
      |> Enum.filter(fn killmail ->
        victim = Map.get(killmail, :victim, %{})
        Map.get(victim, :character_id) == character_id
      end)
      |> Enum.map(fn killmail ->
        victim = Map.get(killmail, :victim, %{})
        Map.get(victim, :damage_taken, 0)
      end)
      |> Enum.sum()
    end
  end

  @doc """
  Build activity timeline for a participant.
  """
  def build_activity_timeline(participant, killmails) do
    character_id = Map.get(participant, :character_id)

    if is_nil(character_id) do
      []
    else
      # Find all killmails where this participant was involved
      relevant_killmails =
        killmails
        |> Enum.filter(fn killmail ->
          participant_involved?(character_id, killmail)
        end)
        |> Enum.sort_by(&Map.get(&1, :killmail_time))

      # Build timeline events
      relevant_killmails
      |> Enum.map(fn killmail ->
        role = determine_participant_role_in_killmail(character_id, killmail)

        %{
          time: Map.get(killmail, :killmail_time),
          killmail_id: Map.get(killmail, :killmail_id),
          role: role,
          damage: get_participant_damage_in_killmail(character_id, killmail, role),
          target: get_target_info(killmail),
          location: Map.get(killmail, :solar_system_id)
        }
      end)
    end
  end

  @doc """
  Calculate contribution score for a participant.
  """
  def calculate_contribution_score(participant, killmails) do
    kills = count_participant_kills(participant, killmails)
    deaths = count_participant_deaths(participant, killmails)
    damage_dealt = calculate_damage_dealt(participant, killmails)
    damage_received = calculate_damage_received(participant, killmails)

    # Calculate base score
    kill_score = kills * 1000
    death_penalty = deaths * 500
    damage_score = damage_dealt / 1000
    survival_bonus = if deaths == 0 and kills > 0, do: 2000, else: 0

    base_score = kill_score - death_penalty + damage_score + survival_bonus

    # Apply multipliers based on performance
    efficiency_ratio =
      if damage_received > 0 do
        damage_dealt / damage_received
      else
        if damage_dealt > 0, do: 10.0, else: 1.0
      end

    final_score = base_score * min(3.0, efficiency_ratio)

    %{
      total_score: Float.round(final_score, 0),
      components: %{
        kill_score: kill_score,
        death_penalty: death_penalty,
        damage_score: Float.round(damage_score, 0),
        survival_bonus: survival_bonus,
        efficiency_multiplier: Float.round(efficiency_ratio, 2)
      },
      rating: categorize_contribution(final_score)
    }
  end

  # Private functions

  defp participant_involved?(character_id, killmail) do
    # Check if participant was victim
    victim_match =
      Map.get(killmail, :victim, %{})
      |> Map.get(:character_id) == character_id

    # Check if participant was attacker
    attacker_match =
      Map.get(killmail, :attackers, [])
      |> Enum.any?(fn attacker ->
        Map.get(attacker, :character_id) == character_id
      end)

    victim_match or attacker_match
  end

  defp determine_participant_role_in_killmail(character_id, killmail) do
    # Check if victim
    victim = Map.get(killmail, :victim, %{})

    if Map.get(victim, :character_id) == character_id do
      :victim
    else
      # Check attackers for specific role
      attackers = Map.get(killmail, :attackers, [])
      attacker = Enum.find(attackers, fn a -> Map.get(a, :character_id) == character_id end)

      if attacker do
        if Map.get(attacker, :final_blow, false) do
          :final_blow
        else
          :attacker
        end
      else
        :unknown
      end
    end
  end

  defp get_participant_damage_in_killmail(character_id, killmail, role) do
    case role do
      :victim ->
        victim = Map.get(killmail, :victim, %{})
        Map.get(victim, :damage_taken, 0)

      _ ->
        attackers = Map.get(killmail, :attackers, [])
        attacker = Enum.find(attackers, fn a -> Map.get(a, :character_id) == character_id end)

        if attacker do
          Map.get(attacker, :damage_done, 0)
        else
          0
        end
    end
  end

  defp get_target_info(killmail) do
    victim = Map.get(killmail, :victim, %{})

    %{
      character_id: Map.get(victim, :character_id),
      character_name: Map.get(victim, :character_name),
      ship_type_id: Map.get(victim, :ship_type_id),
      corporation_name: Map.get(victim, :corporation_name)
    }
  end

  defp analyze_engagement_pattern(participant, killmails) do
    timeline = build_activity_timeline(participant, killmails)

    if Enum.empty?(timeline) do
      %{
        pattern_type: :inactive,
        activity_level: :none,
        peak_activity: nil,
        engagement_style: :unknown
      }
    else
      # Analyze timing patterns
      event_count = length(timeline)
      time_span = calculate_time_span(timeline)

      activity_level = categorize_activity_level(event_count, time_span)
      pattern_type = identify_pattern_type(timeline)
      engagement_style = determine_engagement_style(timeline)

      %{
        pattern_type: pattern_type,
        activity_level: activity_level,
        peak_activity: identify_peak_activity_period(timeline),
        engagement_style: engagement_style,
        event_count: event_count,
        time_span_minutes: Float.round(time_span / 60, 1)
      }
    end
  end

  defp calculate_time_span(timeline) do
    if length(timeline) < 2 do
      0
    else
      first_time = List.first(timeline) |> Map.get(:time)
      last_time = List.last(timeline) |> Map.get(:time)

      # Calculate difference in seconds
      DateTimeUtils.diff(last_time, first_time, :second)
    end
  end

  defp categorize_activity_level(event_count, time_span_seconds) do
    if time_span_seconds < 60 do
      # Less than a minute - use event count only
      case event_count do
        0 -> :none
        1 -> :minimal
        count when count <= 3 -> :low
        count when count <= 6 -> :moderate
        _ -> :high
      end
    else
      # Calculate events per minute
      events_per_minute = event_count / (time_span_seconds / 60)

      cond do
        events_per_minute >= 2.0 -> :very_high
        events_per_minute >= 1.0 -> :high
        events_per_minute >= 0.5 -> :moderate
        events_per_minute >= 0.2 -> :low
        true -> :minimal
      end
    end
  end

  defp identify_pattern_type(timeline) do
    event_count = length(timeline)

    cond do
      event_count == 0 ->
        :inactive

      event_count == 1 ->
        event = List.first(timeline)
        if Map.get(event, :role) == :victim, do: :one_and_done, else: :single_engagement

      event_count <= 3 ->
        :sporadic

      event_count <= 6 ->
        :moderate_engagement

      true ->
        :heavy_engagement
    end
  end

  defp determine_engagement_style(timeline) do
    if Enum.empty?(timeline) do
      :unknown
    else
      victim_events = Enum.count(timeline, &(Map.get(&1, :role) == :victim))
      attacker_events = Enum.count(timeline, &(Map.get(&1, :role) in [:attacker, :final_blow]))

      cond do
        victim_events > 0 and attacker_events == 0 ->
          :defensive_only

        attacker_events > 0 and victim_events == 0 ->
          :aggressive_only

        attacker_events > victim_events * 2 ->
          :primarily_aggressive

        victim_events > attacker_events * 2 ->
          :primarily_defensive

        true ->
          :balanced
      end
    end
  end

  defp identify_peak_activity_period(timeline) do
    if length(timeline) < 3 do
      nil
    else
      # Group events into 5-minute windows and find the busiest
      timeline
      |> Enum.group_by(fn event ->
        time = Map.get(event, :time)
        # Round to 5-minute intervals
        minute = DateTime.to_unix(time, :minute)
        div(minute, 5) * 5
      end)
      |> Enum.max_by(fn {_window, events} -> length(events) end)
      |> case do
        {window_start, events} ->
          %{
            start_time: DateTime.from_unix!(window_start * 60),
            event_count: length(events),
            primary_role: determine_dominant_role(events)
          }

        _ ->
          nil
      end
    end
  end

  defp determine_dominant_role(events) do
    role_counts = Enum.frequencies_by(events, &Map.get(&1, :role))

    {dominant_role, _count} = Enum.max_by(role_counts, fn {_role, count} -> count end)
    dominant_role
  end

  defp build_fleet_timeline(activity_profiles, killmails) do
    # Build overall fleet activity timeline
    killmails
    |> Enum.sort_by(&Map.get(&1, :killmail_time))
    |> Enum.map(fn killmail ->
      time = Map.get(killmail, :killmail_time)
      participants_involved = count_participants_in_killmail(killmail, activity_profiles)

      %{
        time: time,
        killmail_id: Map.get(killmail, :killmail_id),
        participants_involved: participants_involved,
        total_damage: calculate_killmail_damage(killmail),
        location: Map.get(killmail, :solar_system_id)
      }
    end)
  end

  defp count_participants_in_killmail(killmail, activity_profiles) do
    profile_character_ids =
      activity_profiles
      |> Enum.map(&Map.get(&1, :character_id))
      |> MapSet.new()

    # Count victim if in our fleet
    victim_count =
      killmail
      |> Map.get(:victim, %{})
      |> Map.get(:character_id)
      |> (fn char_id -> if char_id in profile_character_ids, do: 1, else: 0 end).()

    # Count attackers in our fleet
    attacker_count =
      killmail
      |> Map.get(:attackers, [])
      |> Enum.count(fn attacker ->
        Map.get(attacker, :character_id) in profile_character_ids
      end)

    victim_count + attacker_count
  end

  defp calculate_killmail_damage(killmail) do
    victim = Map.get(killmail, :victim, %{})
    Map.get(victim, :damage_taken, 0)
  end

  defp summarize_activity_patterns(activity_profiles) do
    total_profiles = length(activity_profiles)

    if total_profiles == 0 do
      %{
        total_participants: 0,
        activity_distribution: %{}
      }
    else
      # Categorize participants by activity level
      activity_distribution =
        activity_profiles
        |> Enum.group_by(fn profile ->
          pattern = Map.get(profile, :engagement_pattern, %{})
          Map.get(pattern, :activity_level, :none)
        end)
        |> Enum.map(fn {level, profiles} ->
          {level, length(profiles)}
        end)
        |> Enum.into(%{})

      # Calculate aggregate stats
      total_kills = Enum.sum(Enum.map(activity_profiles, &Map.get(&1, :kills, 0)))
      total_deaths = Enum.sum(Enum.map(activity_profiles, &Map.get(&1, :deaths, 0)))
      total_damage = Enum.sum(Enum.map(activity_profiles, &Map.get(&1, :damage_dealt, 0)))

      %{
        total_participants: total_profiles,
        activity_distribution: activity_distribution,
        aggregate_stats: %{
          total_kills: total_kills,
          total_deaths: total_deaths,
          total_damage_dealt: total_damage,
          kill_death_ratio:
            if(total_deaths > 0, do: total_kills / total_deaths, else: total_kills),
          average_contribution: calculate_average_contribution(activity_profiles)
        }
      }
    end
  end

  defp calculate_average_contribution(activity_profiles) do
    if Enum.empty?(activity_profiles) do
      0.0
    else
      contribution_scores =
        activity_profiles
        |> Enum.map(fn profile ->
          contribution = Map.get(profile, :contribution_score, %{})
          Map.get(contribution, :total_score, 0)
        end)
        |> Enum.filter(&(&1 > 0))

      if Enum.empty?(contribution_scores) do
        0.0
      else
        Float.round(Enum.sum(contribution_scores) / length(contribution_scores), 1)
      end
    end
  end

  defp identify_engagement_phases(fleet_timeline) do
    if length(fleet_timeline) < 2 do
      [%{phase: :single_event, duration: 0, event_count: length(fleet_timeline)}]
    else
      # Simple phase identification based on time gaps
      timeline_with_gaps = calculate_time_gaps(fleet_timeline)

      # Group events by phases (gap > 5 minutes indicates new phase)
      # 5 minutes in seconds
      phases = group_by_phases(timeline_with_gaps, 300)

      Enum.with_index(phases, 1)
      |> Enum.map(fn {phase_events, index} ->
        first_event = List.first(phase_events)
        last_event = List.last(phase_events)

        duration =
          if first_event == last_event do
            0
          else
            DateTimeUtils.diff(
              Map.get(last_event, :time),
              Map.get(first_event, :time),
              :second
            )
          end

        %{
          phase: "phase_#{index}",
          start_time: Map.get(first_event, :time),
          duration_seconds: duration,
          event_count: length(phase_events),
          peak_intensity: calculate_peak_intensity(phase_events),
          phase_type: categorize_phase_type(phase_events, duration)
        }
      end)
    end
  end

  defp calculate_time_gaps(fleet_timeline) do
    fleet_timeline
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [prev, current] ->
      gap =
        DateTimeUtils.diff(
          Map.get(current, :time),
          Map.get(prev, :time),
          :second
        )

      Map.put(current, :time_gap, gap)
    end)
  end

  defp group_by_phases(timeline_with_gaps, gap_threshold) do
    # Group events into phases based on time gaps
    {phases, current_phase} =
      Enum.reduce(timeline_with_gaps, {[], []}, fn event, {phases, current_phase} ->
        gap = Map.get(event, :time_gap, 0)

        if gap > gap_threshold and not Enum.empty?(current_phase) do
          # Start new phase
          {[Enum.reverse(current_phase) | phases], [event]}
        else
          # Continue current phase
          {phases, [event | current_phase]}
        end
      end)

    final_phases =
      if Enum.empty?(current_phase) do
        phases
      else
        [Enum.reverse(current_phase) | phases]
      end

    Enum.reverse(final_phases)
  end

  defp calculate_peak_intensity(phase_events) do
    if Enum.empty?(phase_events) do
      0.0
    else
      # Calculate max participants involved in any single event
      max_participants =
        phase_events
        |> Enum.map(&Map.get(&1, :participants_involved, 0))
        |> Enum.max()

      max_participants
    end
  end

  defp categorize_phase_type(phase_events, duration_seconds) do
    event_count = length(phase_events)

    cond do
      duration_seconds < 60 and event_count == 1 ->
        :quick_strike

      duration_seconds < 180 and event_count <= 3 ->
        :skirmish

      duration_seconds < 600 ->
        :engagement

      duration_seconds < 1800 ->
        :prolonged_battle

      true ->
        :extended_campaign
    end
  end

  defp count_active_participants(activity_profiles) do
    Enum.count(activity_profiles, fn profile ->
      kills = Map.get(profile, :kills, 0)
      damage = Map.get(profile, :damage_dealt, 0)

      kills > 0 or damage > 0
    end)
  end

  defp identify_peak_activity_time(fleet_timeline) do
    if Enum.empty?(fleet_timeline) do
      nil
    else
      # Find the event with most participants involved
      peak_event =
        fleet_timeline
        |> Enum.max_by(&Map.get(&1, :participants_involved, 0))

      Map.get(peak_event, :time)
    end
  end

  defp calculate_total_engagement_duration(fleet_timeline) do
    if length(fleet_timeline) < 2 do
      0
    else
      first_event = List.first(fleet_timeline)
      last_event = List.last(fleet_timeline)

      DateTimeUtils.diff(
        Map.get(last_event, :time),
        Map.get(first_event, :time),
        :second
      )
    end
  end

  defp categorize_contribution(score) do
    cond do
      score >= 10_000 -> :exceptional
      score >= 5000 -> :high
      score >= 2000 -> :moderate
      score >= 500 -> :low
      score > 0 -> :minimal
      true -> :none
    end
  end
end
