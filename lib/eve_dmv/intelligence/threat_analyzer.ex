defmodule EveDmv.Intelligence.ThreatAnalyzer do
  @moduledoc """
  Analyzes pilots and corporations to assess threat levels and detect bait scenarios.

  Uses historical killmail data and behavioral patterns to provide real-time
  threat assessment for wormhole chain surveillance.
  """

  require Logger
  alias EveDmv.Api
  alias EveDmv.Intelligence.{CharacterStats, SystemInhabitant}
  alias EveDmv.Killmails.KillmailEnriched

  @doc """
  Analyze a pilot and return threat assessment data.

  Returns a map with:
  - threat_level: :friendly, :neutral, :hostile, :unknown
  - threat_score: 0-100 integer
  - bait_probability: 0-100 integer
  - analysis_reason: string explanation
  """
  def analyze_pilot(character_id, corporation_id \\ nil, alliance_id \\ nil) do
    character_stats = get_character_stats(character_id)
    recent_activity = get_recent_activity(character_id)
    associates = find_known_associates(character_id)

    threat_score = calculate_threat_score(character_stats, recent_activity)
    bait_probability = calculate_bait_probability(character_id, associates, recent_activity)
    threat_level = determine_threat_level(threat_score, corporation_id, alliance_id)

    %{
      threat_level: threat_level,
      threat_score: threat_score,
      bait_probability: bait_probability,
      analysis_reason: build_analysis_reason(threat_level, threat_score, bait_probability),
      character_stats: character_stats,
      recent_activity: recent_activity,
      known_associates: length(associates)
    }
  end

  @doc """
  Bulk analyze multiple pilots for efficient threat assessment.
  """
  def analyze_pilots(pilot_list) do
    pilot_list
    |> Task.async_stream(
      fn {character_id, corp_id, alliance_id} ->
        {character_id, analyze_pilot(character_id, corp_id, alliance_id)}
      end,
      max_concurrency: 10,
      timeout: 10_000
    )
    |> Enum.map(fn {:ok, result} -> result end)
    |> Map.new()
  end

  @doc """
  Update threat assessment for a system inhabitant.
  """
  def update_inhabitant_threat(inhabitant_id) do
    case Api.read(SystemInhabitant, inhabitant_id) do
      {:ok, inhabitant} ->
        analysis =
          analyze_pilot(
            inhabitant.character_id,
            inhabitant.corporation_id,
            inhabitant.alliance_id
          )

        Api.update(inhabitant, %{
          threat_level: analysis.threat_level,
          threat_score: analysis.threat_score,
          bait_probability: analysis.bait_probability
        })

      {:error, reason} ->
        Logger.error(
          "Failed to update threat for inhabitant #{inhabitant_id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Private Functions

  defp get_character_stats(character_id) do
    case Api.read(CharacterStats, character_id: character_id) do
      {:ok, [stats]} -> stats
      {:ok, []} -> nil
      {:error, _} -> nil
    end
  end

  defp get_recent_activity(character_id, days_back \\ 30) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days_back, :day)

    # Get recent kills and losses
    kills_query = """
    SELECT COUNT(*) as kill_count, 
           AVG(total_value) as avg_kill_value,
           MAX(killmail_time) as last_kill
    FROM killmails_enriched k
    JOIN participants p ON k.killmail_id = p.killmail_id 
                       AND k.killmail_time = p.killmail_time
    WHERE p.character_id = $1 
      AND k.killmail_time > $2
      AND p.final_blow = true
    """

    losses_query = """
    SELECT COUNT(*) as loss_count,
           AVG(total_value) as avg_loss_value,
           MAX(killmail_time) as last_loss
    FROM killmails_enriched
    WHERE victim_character_id = $1
      AND killmail_time > $2
    """

    with {:ok, %{rows: [[kill_count, avg_kill_value, last_kill]]}} <-
           EveDmv.Repo.query(kills_query, [character_id, cutoff_date]),
         {:ok, %{rows: [[loss_count, avg_loss_value, last_loss]]}} <-
           EveDmv.Repo.query(losses_query, [character_id, cutoff_date]) do
      %{
        recent_kills: kill_count || 0,
        recent_losses: loss_count || 0,
        avg_kill_value: avg_kill_value || 0,
        avg_loss_value: avg_loss_value || 0,
        last_kill: last_kill,
        last_loss: last_loss,
        kill_death_ratio: calculate_kd_ratio(kill_count || 0, loss_count || 0)
      }
    else
      {:error, reason} ->
        Logger.error("Failed to get recent activity for #{character_id}: #{inspect(reason)}")
        %{recent_kills: 0, recent_losses: 0, avg_kill_value: 0, avg_loss_value: 0}
    end
  end

  defp find_known_associates(character_id, days_back \\ 90) do
    cutoff_date = DateTime.add(DateTime.utc_now(), -days_back, :day)

    # Find pilots who frequently appear on killmails with this character
    query = """
    SELECT p2.character_id, p2.character_name, COUNT(*) as shared_kills
    FROM participants p1
    JOIN participants p2 ON p1.killmail_id = p2.killmail_id 
                        AND p1.killmail_time = p2.killmail_time
    JOIN killmails_enriched k ON p1.killmail_id = k.killmail_id 
                             AND p1.killmail_time = k.killmail_time
    WHERE p1.character_id = $1
      AND p2.character_id != $1
      AND k.killmail_time > $2
      AND p1.final_blow = false  -- Not final blow scenarios
      AND p2.final_blow = false
    GROUP BY p2.character_id, p2.character_name
    HAVING COUNT(*) >= 3  -- At least 3 shared kills
    ORDER BY shared_kills DESC
    LIMIT 50
    """

    case EveDmv.Repo.query(query, [character_id, cutoff_date]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [char_id, char_name, shared_count] ->
          %{character_id: char_id, character_name: char_name, shared_kills: shared_count}
        end)

      {:error, reason} ->
        Logger.error("Failed to find associates for #{character_id}: #{inspect(reason)}")
        []
    end
  end

  defp calculate_threat_score(character_stats, recent_activity) do
    # Neutral starting point
    base_score = 50

    # Factor in character stats if available
    stats_modifier =
      if character_stats do
        dangerous_score = character_stats.dangerous_score || 0
        solo_kill_percentage = character_stats.solo_kill_percentage || 0

        # Higher dangerous score and solo activity increases threat
        dangerous_score * 0.3 + solo_kill_percentage * 0.2
      else
        0
      end

    # Factor in recent activity
    activity_modifier =
      cond do
        # Very active killer
        recent_activity.recent_kills > 10 -> 20
        # Active killer
        recent_activity.recent_kills > 5 -> 10
        # Some kills
        recent_activity.recent_kills > 0 -> 5
        # No recent kills
        true -> -10
      end

    # Factor in kill/death ratio
    kd_modifier =
      cond do
        # Very skilled
        recent_activity.kill_death_ratio > 5.0 -> 15
        # Skilled
        recent_activity.kill_death_ratio > 2.0 -> 10
        # Above average
        recent_activity.kill_death_ratio > 1.0 -> 5
        # Average
        recent_activity.kill_death_ratio > 0.5 -> 0
        # Below average
        true -> -5
      end

    # Factor in ship value patterns (expensive losses might indicate wealth/bait)
    value_modifier =
      if recent_activity.avg_loss_value > 1_000_000_000 do
        # High value losses could indicate bait
        10
      else
        0
      end

    final_score = base_score + stats_modifier + activity_modifier + kd_modifier + value_modifier

    # Clamp to 0-100 range
    max(0, min(100, round(final_score)))
  end

  defp calculate_bait_probability(character_id, associates, recent_activity) do
    # Start with 25% base chance
    base_probability = 25

    # High associate count suggests coordination
    associate_modifier =
      cond do
        # Very coordinated
        length(associates) > 20 -> 30
        # Coordinated
        length(associates) > 10 -> 20
        # Some coordination
        length(associates) > 5 -> 10
        true -> 0
      end

    # Solo appearance but with known associates is suspicious
    solo_but_connected =
      if length(associates) > 5 and recent_activity.recent_kills < 2 do
        # Appears solo but has many associates
        25
      else
        0
      end

    # High value losses with low kill activity suggests bait
    bait_pattern =
      if recent_activity.avg_loss_value > 500_000_000 and
           recent_activity.recent_kills < recent_activity.recent_losses do
        # Loses expensive ships but doesn't kill much
        20
      else
        0
      end

    # Recent activity spike might indicate setup
    activity_spike =
      if recent_activity.recent_kills == 0 and recent_activity.recent_losses > 0 do
        # Recent losses but no kills
        15
      else
        0
      end

    final_probability =
      base_probability + associate_modifier + solo_but_connected +
        bait_pattern + activity_spike

    # Clamp to 0-100 range
    max(0, min(100, round(final_probability)))
  end

  defp determine_threat_level(threat_score, corporation_id, alliance_id) do
    # Check for known friendly/hostile corporations
    cond do
      known_friendly?(corporation_id, alliance_id) -> :friendly
      known_hostile?(corporation_id, alliance_id) -> :hostile
      threat_score >= 80 -> :hostile
      # Treat high threats as neutral until confirmed
      threat_score >= 60 -> :neutral
      threat_score >= 40 -> :neutral
      true -> :unknown
    end
  end

  defp known_friendly?(_corporation_id, _alliance_id) do
    # This would check against a corporation's blue list or standings
    false
  end

  defp known_hostile?(_corporation_id, _alliance_id) do
    # This would check against known hostile entities
    false
  end

  defp calculate_kd_ratio(kills, deaths) when deaths == 0 and kills > 0, do: kills * 1.0
  defp calculate_kd_ratio(kills, deaths) when deaths == 0, do: 0.0
  defp calculate_kd_ratio(kills, deaths), do: kills / deaths

  defp build_analysis_reason(threat_level, threat_score, bait_probability) do
    threat_desc =
      case threat_level do
        :hostile -> "High threat pilot"
        :neutral -> "Unknown threat level"
        :friendly -> "Friendly pilot"
        :unknown -> "Insufficient data"
      end

    bait_desc =
      cond do
        bait_probability >= 70 -> "High bait probability"
        bait_probability >= 50 -> "Moderate bait probability"
        bait_probability >= 30 -> "Low bait probability"
        true -> "Unlikely to be bait"
      end

    "#{threat_desc} (#{threat_score}/100). #{bait_desc} (#{bait_probability}%)."
  end
end
