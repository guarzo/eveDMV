defmodule EveDmv.Contexts.Corporation.Core.MemberActivityAnalyzer do
  @moduledoc """
  Analyzes member activity patterns within corporations including participation rates,
  activity trends, and member engagement metrics.
  
  Consolidates functionality from:
  - Corporation Analysis member activity analyzer
  - Corporation Intelligence member activity analysis
  """
  
  alias EveDmv.Platform.Database.{CorporationRepository, CharacterRepository}
  alias EveDmv.Platform.Cache.Corporation.CorporationCache
  
  require Logger
  
  @cache_ttl :timer.hours(4)
  
  @doc """
  Analyze member activity for a corporation.
  
  Options:
    - time_range: Analysis period (default: last 90 days)
    - include_trends: Include trend analysis
    - include_patterns: Include activity pattern analysis
  """
  def analyze_member_activity(corporation_id, opts \\ []) do
    cache_key = {:member_activity, corporation_id, opts}
    
    case CorporationCache.get(cache_key) do
      nil ->
        result = perform_member_activity_analysis(corporation_id, opts)
        if match?({:ok, _}, result) do
          {:ok, analysis} = result
          CorporationCache.put(cache_key, analysis, ttl: @cache_ttl)
        end
        result
        
      cached_result ->
        {:ok, cached_result}
    end
  end
  
  @doc """
  Get summary of member activity.
  """
  def get_member_activity_summary(corporation_id) do
    case analyze_member_activity(corporation_id) do
      {:ok, analysis} -> {:ok, analysis.summary}
      error -> error
    end
  end
  
  @doc """
  Get member participation rates.
  """
  def get_member_participation_rates(corporation_id) do
    case analyze_member_activity(corporation_id) do
      {:ok, analysis} -> {:ok, analysis.participation_rates}
      error -> error
    end
  end
  
  @doc """
  Analyze member activity trends over time.
  """
  def analyze_member_trends(corporation_id, time_period) do
    with {:ok, historical_data} <- get_historical_member_data(corporation_id, time_period) do
      trends = %{
        member_count_trend: analyze_member_count_trend(historical_data),
        activity_trend: analyze_activity_trend(historical_data),
        retention_trend: analyze_retention_trend(historical_data),
        engagement_trend: analyze_engagement_trend(historical_data)
      }
      
      {:ok, trends}
    end
  end
  
  @doc """
  Identify inactive members.
  """
  def get_inactive_members(corporation_id, threshold \\ 30) do
    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id) do
      cutoff_date = DateTime.utc_now() |> DateTime.add(-threshold, :day)
      
      inactive_members = members
      |> Enum.filter(fn member ->
        is_nil(member.last_seen) || 
        DateTime.compare(member.last_seen, cutoff_date) == :lt
      end)
      |> Enum.map(fn member ->
        %{
          character_id: member.character_id,
          character_name: member.character_name,
          last_seen: member.last_seen,
          days_inactive: calculate_days_inactive(member.last_seen),
          join_date: member.join_date,
          tenure: calculate_tenure(member.join_date)
        }
      end)
      |> Enum.sort_by(& &1.days_inactive, :desc)
      
      {:ok, inactive_members}
    end
  end
  
  @doc """
  Get top performing members.
  """
  def get_top_performers(corporation_id, limit \\ 10) do
    with {:ok, analysis} <- analyze_member_activity(corporation_id) do
      top_performers = analysis.member_metrics
      |> Enum.sort_by(& &1.activity_score, :desc)
      |> Enum.take(limit)
      |> Enum.map(fn member ->
        %{
          character_id: member.character_id,
          character_name: member.character_name,
          activity_score: member.activity_score,
          participation_rate: member.participation_rate,
          recent_kills: member.recent_kills,
          contribution_rating: member.contribution_rating
        }
      end)
      
      {:ok, top_performers}
    end
  end
  
  # Private Functions
  
  defp perform_member_activity_analysis(corporation_id, opts) do
    Logger.info("Analyzing member activity for corporation #{corporation_id}")
    
    time_range = Keyword.get(opts, :time_range, days: 90)
    
    with {:ok, members} <- CorporationRepository.get_corporation_members(corporation_id),
         {:ok, activity_data} <- gather_member_activity_data(members, time_range),
         {:ok, participation_data} <- analyze_participation_data(activity_data) do
      
      analysis = %{
        corporation_id: corporation_id,
        analysis_period: time_range,
        total_members: length(members),
        summary: build_activity_summary(activity_data, participation_data),
        member_metrics: build_member_metrics(activity_data),
        participation_rates: build_participation_rates(participation_data),
        activity_distribution: analyze_activity_distribution(activity_data),
        engagement_patterns: analyze_engagement_patterns(activity_data),
        member_segments: segment_members_by_activity(activity_data),
        recommendations: generate_activity_recommendations(activity_data, participation_data),
        analyzed_at: DateTime.utc_now()
      }
      
      analysis = if Keyword.get(opts, :include_trends, false) do
        Map.put(analysis, :trends, analyze_activity_trends(corporation_id, activity_data))
      else
        analysis
      end
      
      analysis = if Keyword.get(opts, :include_patterns, false) do
        Map.put(analysis, :patterns, analyze_detailed_patterns(activity_data))
      else
        analysis
      end
      
      {:ok, analysis}
    end
  end
  
  defp gather_member_activity_data(members, time_range) do
    start_date = calculate_start_date(time_range)
    
    # Gather activity data for all members in parallel
    activity_data = members
    |> Task.async_stream(fn member ->
      {member.character_id, collect_member_activity(member, start_date)}
    end, max_concurrency: 20, timeout: 15_000)
    |> Enum.reduce(%{}, fn
      {:ok, {char_id, {:ok, activity}}}, acc ->
        Map.put(acc, char_id, activity)
        
      {:ok, {char_id, {:error, reason}}}, acc ->
        Logger.warning("Failed to get activity for character #{char_id}: #{inspect(reason)}")
        Map.put(acc, char_id, %{active: false, error: reason})
        
      {:exit, reason}, acc ->
        Logger.error("Activity collection task failed: #{inspect(reason)}")
        acc
    end)
    
    {:ok, activity_data}
  end
  
  defp calculate_start_date(days: days) do
    DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
  end
  
  defp calculate_start_date(weeks: weeks) do
    DateTime.utc_now() |> DateTime.add(-weeks * 7 * 24 * 60 * 60, :second)
  end
  
  defp collect_member_activity(member, start_date) do
    with {:ok, killmails} <- CharacterRepository.get_character_killmails_since(member.character_id, start_date),
         {:ok, character_stats} <- CharacterRepository.get_character_stats(member.character_id) do
      
      activity = %{
        character_id: member.character_id,
        character_name: member.character_name,
        join_date: member.join_date,
        last_seen: member.last_seen,
        recent_kills: length(Enum.filter(killmails, &(&1.victim.character_id != member.character_id))),
        recent_losses: length(Enum.filter(killmails, &(&1.victim.character_id == member.character_id))),
        total_killmails: length(killmails),
        activity_score: calculate_activity_score(killmails, member, character_stats),
        participation_days: calculate_participation_days(killmails),
        avg_daily_activity: calculate_avg_daily_activity(killmails, start_date),
        peak_activity_hours: analyze_peak_hours(killmails),
        ship_diversity: analyze_ship_diversity(killmails, member.character_id),
        gang_participation: analyze_gang_participation(killmails),
        contribution_rating: calculate_contribution_rating(killmails, character_stats),
        consistency_score: calculate_consistency_score(killmails, start_date),
        engagement_quality: assess_engagement_quality(killmails, member.character_id)
      }
      
      {:ok, activity}
    end
  end
  
  defp calculate_activity_score(killmails, member, character_stats) do
    base_score = length(killmails) * 2  # Base activity from killmail count
    
    # Tenure bonus (longer members get slightly higher scores for same activity)
    tenure_days = if member.join_date do
      DateTime.diff(DateTime.utc_now(), member.join_date, :day)
    else
      0
    end
    tenure_bonus = min(tenure_days / 365 * 5, 10)  # Max 10 points for tenure
    
    # Recency bonus (recent activity weighted higher)
    recency_bonus = if member.last_seen do
      days_since = DateTime.diff(DateTime.utc_now(), member.last_seen, :day)
      max(0, 20 - days_since)  # More recent = higher bonus
    else
      0
    end
    
    # Performance bonus from character stats
    performance_bonus = if character_stats && character_stats.kill_death_ratio do
      min(Decimal.to_float(character_stats.kill_death_ratio) * 5, 15)
    else
      0
    end
    
    total_score = base_score + tenure_bonus + recency_bonus + performance_bonus
    Float.round(min(total_score, 100), 1)
  end
  
  defp calculate_participation_days(killmails) do
    killmails
    |> Enum.map(fn km -> DateTime.to_date(km.killmail_time) end)
    |> Enum.uniq()
    |> length()
  end
  
  defp calculate_avg_daily_activity(killmails, start_date) do
    days_in_period = DateTime.diff(DateTime.utc_now(), start_date, :day)
    
    if days_in_period > 0 do
      Float.round(length(killmails) / days_in_period, 2)
    else
      0.0
    end
  end
  
  defp analyze_peak_hours(killmails) do
    killmails
    |> Enum.map(fn km -> DateTime.to_time(km.killmail_time).hour end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, _count} -> hour end)
  end
  
  defp analyze_ship_diversity(killmails, character_id) do
    ships_used = killmails
    |> Enum.filter(fn km ->
      # Get ships used by this character (either as victim or attacker)
      if km.victim.character_id == character_id do
        km.victim.ship_type_id
      else
        case Enum.find(km.attackers, fn att -> att.character_id == character_id end) do
          nil -> nil
          attacker -> attacker.ship_type_id
        end
      end
    end)
    |> Enum.filter(& &1)
    |> Enum.uniq()
    |> length()
    
    ships_used
  end
  
  defp analyze_gang_participation(killmails) do
    if Enum.empty?(killmails) do
      %{solo_ratio: 0, avg_gang_size: 1, gang_preference: :unknown}
    else
      gang_sizes = Enum.map(killmails, fn km -> length(km.attackers) end)
      solo_count = Enum.count(gang_sizes, &(&1 == 1))
      avg_size = Enum.sum(gang_sizes) / length(gang_sizes)
      
      %{
        solo_ratio: Float.round(solo_count / length(killmails), 2),
        avg_gang_size: Float.round(avg_size, 1),
        gang_preference: determine_gang_preference(avg_size, solo_count / length(killmails))
      }
    end
  end
  
  defp determine_gang_preference(avg_size, solo_ratio) do
    cond do
      solo_ratio > 0.7 -> :solo_specialist
      avg_size <= 5 -> :small_gang
      avg_size <= 20 -> :medium_gang
      true -> :fleet_operations
    end
  end
  
  defp calculate_contribution_rating(killmails, character_stats) do
    # Base rating from activity level
    activity_rating = min(length(killmails) / 10, 5)  # Max 5 points from activity
    
    # Performance rating
    performance_rating = if character_stats && character_stats.kill_death_ratio do
      min(Decimal.to_float(character_stats.kill_death_ratio), 5)  # Max 5 points from K/D
    else
      2.5  # Average assumption
    end
    
    Float.round(activity_rating + performance_rating, 1)
  end
  
  defp calculate_consistency_score(killmails, start_date) do
    if length(killmails) < 5 do
      0.0
    else
      # Group killmails by week
      weeks = killmails
      |> Enum.group_by(fn km ->
        {Date.year(km.killmail_time), Date.week_of_year(km.killmail_time)}
      end)
      |> Map.values()
      |> Enum.map(&length/1)
      
      if length(weeks) < 2 do
        0.0
      else
        # Calculate coefficient of variation (lower = more consistent)
        mean = Enum.sum(weeks) / length(weeks)
        variance = weeks
        |> Enum.map(fn count -> :math.pow(count - mean, 2) end)
        |> Enum.sum()
        |> Kernel./(length(weeks))
        
        cv = if mean > 0, do: :math.sqrt(variance) / mean, else: 1
        consistency = max(0, 100 * (1 - cv))
        
        Float.round(consistency, 1)
      end
    end
  end
  
  defp assess_engagement_quality(killmails, character_id) do
    if Enum.empty?(killmails) do
      %{quality_score: 0, assessment: :no_data}
    else
      kills = Enum.filter(killmails, fn km -> km.victim.character_id != character_id end)
      losses = Enum.filter(killmails, fn km -> km.victim.character_id == character_id end)
      
      # Calculate quality metrics
      survival_rate = if length(killmails) > 0 do
        length(kills) / length(killmails)
      else
        0
      end
      
      avg_kill_value = if Enum.empty?(kills) do
        0
      else
        total_value = kills |> Enum.map(& &1.total_value) |> Enum.sum()
        total_value / length(kills)
      end
      
      # Quality score calculation
      quality_score = (survival_rate * 50) + (min(avg_kill_value / 100_000_000, 1) * 50)
      
      %{
        quality_score: Float.round(quality_score, 1),
        survival_rate: Float.round(survival_rate * 100, 1),
        avg_kill_value: avg_kill_value,
        assessment: assess_quality_level(quality_score)
      }
    end
  end
  
  defp assess_quality_level(score) do
    cond do
      score >= 80 -> :excellent
      score >= 60 -> :good
      score >= 40 -> :average
      score >= 20 -> :below_average
      true -> :poor
    end
  end
  
  defp analyze_participation_data(activity_data) do
    # Analyze overall participation patterns
    active_members = activity_data
    |> Enum.filter(fn {_char_id, data} -> data.total_killmails > 0 end)
    |> length()
    
    total_members = map_size(activity_data)
    
    participation_rates = %{
      overall_participation: if(total_members > 0, do: active_members / total_members, else: 0),
      highly_active: count_highly_active_members(activity_data) / max(total_members, 1),
      moderately_active: count_moderately_active_members(activity_data) / max(total_members, 1),
      barely_active: count_barely_active_members(activity_data) / max(total_members, 1),
      inactive: count_inactive_members(activity_data) / max(total_members, 1)
    }
    
    {:ok, participation_rates}
  end
  
  defp count_highly_active_members(activity_data) do
    Enum.count(activity_data, fn {_char_id, data} ->
      data.activity_score >= 70
    end)
  end
  
  defp count_moderately_active_members(activity_data) do
    Enum.count(activity_data, fn {_char_id, data} ->
      data.activity_score >= 30 and data.activity_score < 70
    end)
  end
  
  defp count_barely_active_members(activity_data) do
    Enum.count(activity_data, fn {_char_id, data} ->
      data.activity_score > 0 and data.activity_score < 30
    end)
  end
  
  defp count_inactive_members(activity_data) do
    Enum.count(activity_data, fn {_char_id, data} ->
      data.activity_score == 0 or data.total_killmails == 0
    end)
  end
  
  defp build_activity_summary(activity_data, participation_data) do
    total_killmails = activity_data
    |> Map.values()
    |> Enum.map(& &1.total_killmails)
    |> Enum.sum()
    
    avg_activity_score = if map_size(activity_data) > 0 do
      activity_data
      |> Map.values()
      |> Enum.map(& &1.activity_score)
      |> Enum.sum()
      |> Kernel./(map_size(activity_data))
    else
      0
    end
    
    %{
      total_members: map_size(activity_data),
      active_members: round(participation_data.overall_participation * map_size(activity_data)),
      total_killmails: total_killmails,
      avg_activity_score: Float.round(avg_activity_score, 1),
      participation_rate: Float.round(participation_data.overall_participation * 100, 1),
      activity_trend: determine_activity_trend(activity_data),
      health_status: assess_corporation_activity_health(participation_data)
    }
  end
  
  defp determine_activity_trend(activity_data) do
    # Simplified trend analysis based on recent vs older activity
    # Would need historical data for proper trend analysis
    recent_activity = activity_data
    |> Map.values()
    |> Enum.map(& &1.avg_daily_activity)
    |> Enum.sum()
    
    cond do
      recent_activity > 50 -> :increasing
      recent_activity < 20 -> :decreasing
      true -> :stable
    end
  end
  
  defp assess_corporation_activity_health(participation_data) do
    cond do
      participation_data.overall_participation > 0.7 -> :excellent
      participation_data.overall_participation > 0.5 -> :good
      participation_data.overall_participation > 0.3 -> :concerning
      participation_data.overall_participation > 0.1 -> :poor
      true -> :critical
    end
  end
  
  defp build_member_metrics(activity_data) do
    activity_data
    |> Enum.map(fn {char_id, data} ->
      Map.put(data, :character_id, char_id)
    end)
    |> Enum.sort_by(& &1.activity_score, :desc)
  end
  
  defp build_participation_rates(participation_data) do
    participation_data
    |> Enum.map(fn {level, rate} ->
      {level, Float.round(rate * 100, 1)}
    end)
    |> Map.new()
  end
  
  defp analyze_activity_distribution(activity_data) do
    scores = activity_data
    |> Map.values()
    |> Enum.map(& &1.activity_score)
    
    %{
      distribution: %{
        "0-20": Enum.count(scores, &(&1 >= 0 and &1 < 20)),
        "20-40": Enum.count(scores, &(&1 >= 20 and &1 < 40)),
        "40-60": Enum.count(scores, &(&1 >= 40 and &1 < 60)),
        "60-80": Enum.count(scores, &(&1 >= 60 and &1 < 80)),
        "80-100": Enum.count(scores, &(&1 >= 80))
      },
      statistics: %{
        mean: if(Enum.empty?(scores), do: 0, else: Enum.sum(scores) / length(scores)),
        median: calculate_median(scores),
        std_dev: calculate_std_dev(scores)
      }
    }
  end
  
  defp calculate_median([]), do: 0
  defp calculate_median(scores) do
    sorted = Enum.sort(scores)
    len = length(sorted)
    
    if rem(len, 2) == 0 do
      (Enum.at(sorted, div(len, 2) - 1) + Enum.at(sorted, div(len, 2))) / 2
    else
      Enum.at(sorted, div(len, 2))
    end
  end
  
  defp calculate_std_dev([]), do: 0
  defp calculate_std_dev(scores) do
    mean = Enum.sum(scores) / length(scores)
    variance = scores
    |> Enum.map(fn score -> :math.pow(score - mean, 2) end)
    |> Enum.sum()
    |> Kernel./(length(scores))
    
    :math.sqrt(variance)
  end
  
  defp analyze_engagement_patterns(activity_data) do
    # Analyze common engagement patterns across members
    patterns = %{
      solo_preference: calculate_solo_preference_ratio(activity_data),
      avg_gang_size: calculate_avg_corporation_gang_size(activity_data),
      peak_activity_hours: identify_corporation_peak_hours(activity_data),
      ship_diversity: calculate_corporation_ship_diversity(activity_data),
      engagement_styles: identify_common_engagement_styles(activity_data)
    }
    
    patterns
  end
  
  defp calculate_solo_preference_ratio(activity_data) do
    solo_ratios = activity_data
    |> Map.values()
    |> Enum.map(fn data -> data.gang_participation.solo_ratio end)
    |> Enum.filter(&(&1 > 0))
    
    if Enum.empty?(solo_ratios) do
      0.0
    else
      Enum.sum(solo_ratios) / length(solo_ratios)
    end
  end
  
  defp calculate_avg_corporation_gang_size(activity_data) do
    gang_sizes = activity_data
    |> Map.values()
    |> Enum.map(fn data -> data.gang_participation.avg_gang_size end)
    |> Enum.filter(&(&1 > 0))
    
    if Enum.empty?(gang_sizes) do
      1.0
    else
      Enum.sum(gang_sizes) / length(gang_sizes)
    end
  end
  
  defp identify_corporation_peak_hours(activity_data) do
    # Aggregate peak hours across all members
    all_peak_hours = activity_data
    |> Map.values()
    |> Enum.flat_map(& &1.peak_activity_hours)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_hour, count} -> count end, :desc)
    |> Enum.take(3)
    |> Enum.map(fn {hour, _count} -> hour end)
    
    all_peak_hours
  end
  
  defp calculate_corporation_ship_diversity(activity_data) do
    diversities = activity_data
    |> Map.values()
    |> Enum.map(& &1.ship_diversity)
    |> Enum.filter(&(&1 > 0))
    
    if Enum.empty?(diversities) do
      0
    else
      Enum.sum(diversities) / length(diversities)
    end
  end
  
  defp identify_common_engagement_styles(activity_data) do
    styles = activity_data
    |> Map.values()
    |> Enum.map(fn data -> data.gang_participation.gang_preference end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_style, count} -> count end, :desc)
    
    styles
  end
  
  defp segment_members_by_activity(activity_data) do
    %{
      elite_performers: filter_members_by_score(activity_data, 80, 100),
      high_performers: filter_members_by_score(activity_data, 60, 79),
      average_performers: filter_members_by_score(activity_data, 30, 59),
      low_performers: filter_members_by_score(activity_data, 1, 29),
      inactive_members: filter_members_by_score(activity_data, 0, 0)
    }
  end
  
  defp filter_members_by_score(activity_data, min_score, max_score) do
    activity_data
    |> Enum.filter(fn {_char_id, data} ->
      data.activity_score >= min_score and data.activity_score <= max_score
    end)
    |> Enum.map(fn {char_id, data} ->
      %{
        character_id: char_id,
        character_name: data.character_name,
        activity_score: data.activity_score,
        recent_kills: data.recent_kills,
        participation_days: data.participation_days
      }
    end)
    |> Enum.sort_by(& &1.activity_score, :desc)
  end
  
  defp generate_activity_recommendations(activity_data, participation_data) do
    recommendations = []
    
    # Low participation recommendations
    recommendations = if participation_data.overall_participation < 0.4 do
      ["Consider member engagement initiatives - low overall participation rate" | recommendations]
    else
      recommendations
    end
    
    # Inactive member recommendations
    inactive_count = count_inactive_members(activity_data)
    total_count = map_size(activity_data)
    
    recommendations = if inactive_count / total_count > 0.3 do
      ["Review inactive members for potential removal - #{inactive_count} inactive out of #{total_count}" | recommendations]
    else
      recommendations
    end
    
    # Activity concentration recommendations
    highly_active = count_highly_active_members(activity_data)
    
    recommendations = if highly_active < 5 and total_count > 20 do
      ["Identify and develop more highly active members for leadership roles" | recommendations]
    else
      recommendations
    end
    
    Enum.reverse(recommendations)
  end
  
  defp analyze_activity_trends(_corporation_id, _activity_data) do
    # Placeholder for historical trend analysis
    %{
      member_growth: :stable,
      activity_growth: :stable,
      engagement_trend: :stable,
      retention_trend: :stable
    }
  end
  
  defp analyze_detailed_patterns(_activity_data) do
    # Placeholder for detailed pattern analysis
    %{
      timezone_patterns: %{},
      weekly_patterns: %{},
      seasonal_patterns: %{}
    }
  end
  
  defp get_historical_member_data(_corporation_id, _time_period) do
    # Placeholder for historical data retrieval
    {:ok, []}
  end
  
  defp analyze_member_count_trend(_historical_data) do
    :stable
  end
  
  defp analyze_activity_trend(_historical_data) do
    :stable
  end
  
  defp analyze_retention_trend(_historical_data) do
    :stable
  end
  
  defp analyze_engagement_trend(_historical_data) do
    :stable
  end
  
  defp calculate_days_inactive(nil), do: nil
  defp calculate_days_inactive(last_seen) do
    DateTime.diff(DateTime.utc_now(), last_seen, :day)
  end
  
  defp calculate_tenure(nil), do: 0
  defp calculate_tenure(join_date) do
    DateTime.diff(DateTime.utc_now(), join_date, :day)
  end
end