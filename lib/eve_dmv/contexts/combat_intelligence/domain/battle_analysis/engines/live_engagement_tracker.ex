defmodule EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Engines.LiveEngagementTracker do
  @moduledoc """
  Tracks and analyzes live battle engagements in real-time.

  Responsible for:
  - Managing active engagement state per system
  - Updating engagement data with new killmails
  - Performing real-time analysis of ongoing battles
  - Tracking engagement progression and participant flow
  - Cleaning up stale engagements
  """
  """

  alias EveDmv.Contexts.CombatIntelligence.Domain.BattleAnalysis.Processors.PerformanceCalculator
  alias EveDmv.Core.Utils.DateTimeUtils
  require Logger

  # Constants
  @stale_engagement_minutes 30

  @doc """
  Initialize tracking for a new engagement or update existing.
  """
  def track_engagement(engagement_data, killmail) do
    engagement_data
    |> update_with_killmail(killmail)
    |> update_participants(killmail)
    |> update_analysis_timestamp()
  end

  @doc """
  Update engagement data with new killmails.
  """
  def update_engagement_data(engagement, new_kills) do
    updated =
      engagement
      |> Map.update(:killmails, new_kills, &(&1 ++ new_kills))
      |> Map.put(:last_activity, DateTime.utc_now())
      |> update_participant_tracking(new_kills)

    {:ok, updated}
  end

  @doc """
  Perform real-time analysis on a live engagement.
  """
  def analyze_live_engagement(engagement) do
    participant_count = map_size(engagement.participants)
    kill_rate = PerformanceCalculator.calculate_kill_rate(engagement.killmails)

    analysis = %{
      system_id: engagement.system_id,
      start_time: engagement.start_time,
      last_activity: engagement.last_activity,
      duration_seconds: DateTimeUtils.diff(engagement.last_activity, engagement.start_time, :second),
      participant_count: participant_count,
      kill_count: length(engagement.killmails),
      kill_rate_per_minute: kill_rate,
      engagement_intensity:
        calculate_engagement_intensity(engagement.killmails, participant_count),
      engagement_scale: classify_engagement_scale(participant_count),
      projected_outcome: predict_engagement_outcome(engagement),
      recommendation: generate_live_recommendation(engagement)
    }

    {:ok, analysis}
  end

  @doc """
  Clean up stale engagements older than threshold.
  """
  def cleanup_stale_engagements(active_engagements) do
    cutoff_time = DateTimeUtils.add(DateTime.utc_now(), -@stale_engagement_minutes * 60, :second)

    active_engagements
    |> Enum.reject(fn {_system_id, engagement} ->
      DateTimeUtils.compare(engagement.last_activity, cutoff_time) == :lt
    end)
    |> Map.new()
  end

  @doc """
  Initialize a new engagement from a killmail.
  """
  def initialize_engagement(killmail) do
    %{
      system_id: killmail.system_id,
      start_time: killmail.timestamp,
      last_activity: killmail.timestamp,
      killmails: [killmail],
      participants: extract_participants_from_killmail(killmail)
    }
  end

  # Private helper functions

  defp update_with_killmail(engagement, killmail) do
    engagement
    |> Map.update(:killmails, [killmail], &[killmail | &1])
    |> Map.put(:last_activity, killmail.timestamp)
  end

  defp update_participants(engagement, killmail) do
    new_participants = extract_participants_from_killmail(killmail)

    updated_participants =
      Map.merge(engagement.participants, new_participants, fn _k, v1, v2 ->
        %{
          kills: v1.kills + v2.kills,
          losses: v1.losses + v2.losses,
          last_seen: max_datetime(v1.last_seen, v2.last_seen)
        }
      end)

    Map.put(engagement, :participants, updated_participants)
  end

  defp update_analysis_timestamp(engagement) do
    Map.put(engagement, :last_analysis, DateTime.utc_now())
  end

  defp update_participant_tracking(engagement, new_kills) do
    Enum.reduce(new_kills, engagement, fn kill, acc ->
      update_participants(acc, kill)
    end)
  end

  defp extract_participants_from_killmail(killmail) do
    victim = %{
      killmail.victim_id => %{
        kills: 0,
        losses: 1,
        last_seen: killmail.timestamp
      }
    }

    attackers =
      killmail.attackers
      |> Enum.map(fn attacker ->
        {attacker.character_id,
         %{
           kills: 1,
           losses: 0,
           last_seen: killmail.timestamp
         }}
      end)
      |> Map.new()

    Map.merge(victim, attackers)
  end

  defp calculate_engagement_intensity(killmails, participant_count) do
    if participant_count == 0 do
      0.0
    else
      # Kills per participant per minute
      duration_minutes = calculate_duration_minutes(killmails)

      if duration_minutes > 0 do
        length(killmails) / participant_count / duration_minutes * 100
      else
        # Max intensity for instant battles
        100.0
      end
    end
  end

  defp calculate_duration_minutes(killmails) do
    if length(killmails) < 2 do
      # Minimum 1 minute
      1
    else
      first = List.first(killmails).timestamp
      last = List.last(killmails).timestamp
      max(DateTimeUtils.diff(last, first, :second) / 60, 1)
    end
  end

  defp classify_engagement_scale(participant_count) do
    cond do
      participant_count < 5 -> :skirmish
      participant_count < 15 -> :small_gang
      participant_count < 30 -> :medium_gang
      participant_count < 75 -> :fleet
      participant_count < 150 -> :large_fleet
      true -> :massive_battle
    end
  end

  defp predict_engagement_outcome(engagement) do
    # Simple prediction based on kill patterns
    recent_kills = Enum.take(engagement.killmails, -5)

    if length(recent_kills) < 3 do
      :too_early
    else
      # Analyze momentum
      victim_corps =
        recent_kills
        |> Enum.map(& &1.victim_corporation_id)
        |> Enum.frequencies()

      # If one corp is taking most losses, they're likely losing
      max_losses = victim_corps |> Map.values() |> Enum.max(fn -> 0 end)

      if max_losses >= 3 do
        :one_sided_victory_likely
      else
        :balanced_fight
      end
    end
  end

  defp generate_live_recommendation(engagement) do
    scale = classify_engagement_scale(map_size(engagement.participants))

    intensity =
      calculate_engagement_intensity(engagement.killmails, map_size(engagement.participants))

    cond do
      scale in [:large_fleet, :massive_battle] ->
        "Major fleet engagement detected - Consider strategic assets"

      intensity > 50 ->
        "High intensity combat - Rapid reinforcement recommended"

      predict_engagement_outcome(engagement) == :one_sided_victory_likely ->
        "Battle momentum shifting - Evaluate tactical withdrawal"

      true ->
        "Standard engagement progression - Monitor for escalation"
    end
  end

  defp max_datetime(dt1, dt2) do
    if DateTimeUtils.compare(dt1, dt2) == :gt, do: dt1, else: dt2
  end
end
