defmodule EveDmv.Intelligence.Analyzers.CorporationAnalyzer do
  @moduledoc """
  **DEPRECATED**: Use `EveDmv.Contexts.Corporation.Core.CorporationAnalyzer` instead.

  This module is deprecated and will be removed in a future release.
  The canonical corporation analyzer is in the Corporation context.

  ---

  Corporation intelligence analysis module.

  Provides focused analysis of corporation-level patterns, member correlations,
  and coordination metrics extracted from killmail data.

  Implements the Intelligence.Analyzer behavior for consistent interface and telemetry.
  """

  use EveDmv.Intelligence.Analyzer

  alias EveDmv.Core.Utils.DateTimeUtils
  alias EveDmv.Intelligence.Core.CacheHelper
  alias EveDmv.Intelligence.Core.Config
  alias EveDmv.Intelligence.Core.TimeoutHelper
  alias EveDmv.Intelligence.Core.ValidationHelper
  alias EveDmv.Platform.Database.QueryUtils
  require Logger

  @type member_correlations :: %{
          shared_operations: map(),
          loss_distribution: map(),
          activity_correlation: map()
        }

  @type coordination_analysis :: %{
          coordination_score: float(),
          fleet_participation: map(),
          operational_synergy: map()
        }

  # Behavior implementations

  @impl EveDmv.Intelligence.Analyzer
  def analysis_type, do: :corporation

  @impl EveDmv.Intelligence.Analyzer
  def validate_params(corporation_id, opts) do
    ValidationHelper.validate_corporation_analysis(corporation_id, opts)
  end

  @impl EveDmv.Intelligence.Analyzer
  def analyze(corporation_id, opts \\ %{}) do
    cache_ttl = Config.get_cache_ttl(:corporation)

    CacheHelper.get_or_compute(:corporation, corporation_id, cache_ttl, fn ->
      do_analyze_corporation(corporation_id, opts)
    end)
  end

  @impl EveDmv.Intelligence.Analyzer
  def invalidate_cache(corporation_id) do
    CacheHelper.invalidate_analysis(:corporation, corporation_id)
  end

  @doc """
  Legacy interface for backwards compatibility.
  """
  def analyze_corporation(corporation_id) do
    case analyze_with_telemetry(corporation_id, %{}) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        Logger.error("Corporation analysis failed for #{corporation_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Analyze member correlations within a corporation.

  Identifies patterns in member behavior, shared operations,
  and coordination metrics.
  """
  @spec analyze_member_correlations(list()) :: map()
  def analyze_member_correlations(members) when is_list(members) do
    %{
      shared_operations: analyze_shared_operations(members),
      loss_distribution: analyze_loss_distribution(members),
      activity_correlation: calculate_activity_correlation(members)
    }
  end

  @doc """
  Analyze corporation activity patterns.

  Examines temporal patterns, engagement types, and operational focus.
  """
  @spec analyze_activity_patterns(list()) :: map()
  def analyze_activity_patterns(members) when is_list(members) do
    %{
      primary_timezones: identify_primary_timezones(members),
      engagement_types: categorize_engagement_types(members),
      operational_focus: determine_operational_focus(members)
    }
  end

  @doc """
  Analyze corporation risk distribution.

  Evaluates risk levels across members and identifies patterns.
  """
  @spec analyze_risk_distribution(list()) :: map()
  def analyze_risk_distribution(members) when is_list(members) do
    risk_scores = Enum.map(members, &calculate_member_risk/1)

    %{
      average_risk: Enum.sum(risk_scores) / length(risk_scores),
      risk_variance: calculate_variance(risk_scores),
      high_risk_count: Enum.count(risk_scores, &(&1 > 70)),
      risk_distribution: categorize_risk_levels(risk_scores)
    }
  end

  @doc """
  Analyze member coordination patterns.

  Identifies coordination levels and operational patterns.
  """
  @spec analyze_coordination(list()) :: map()
  def analyze_coordination(members) when is_list(members) do
    %{
      coordination_score: calculate_coordination_score(members),
      fleet_participation: analyze_fleet_participation(members),
      operational_synergy: measure_operational_synergy(members)
    }
  end

  # Private helper functions

  # Private implementation functions

  defp do_analyze_corporation(corporation_id, opts) do
    days_back = Map.get(opts, :days_back, 30)
    limit = Map.get(opts, :limit, 1000)

    with {:ok, killmails} <-
           TimeoutHelper.with_default_timeout(
             fn -> get_corporation_killmails(corporation_id, days_back, limit) end,
             :query
           ),
         {:ok, members} <-
           TimeoutHelper.with_default_timeout(
             fn -> extract_corporation_members(killmails, corporation_id) end,
             :analysis
           ) do
      perform_corporation_analysis(members, corporation_id)
    else
      {:timeout, _} ->
        # Return minimal analysis on timeout
        perform_minimal_analysis(corporation_id)

      {:error, reason} ->
        Logger.error("Corporation analysis failed: #{inspect(reason)}")
        # Return minimal analysis on error
        perform_minimal_analysis(corporation_id)
    end
  end

  defp get_corporation_killmails(corporation_id, days_back, limit) do
    # Get recent killmails involving the corporation
    killmails =
      QueryUtils.query_killmails_by_corporation(
        corporation_id,
        DateTimeUtils.add(DateTime.utc_now(), -days_back, :day),
        DateTime.utc_now(),
        limit
      )

    {:ok, killmails}
  rescue
    error ->
      Logger.error("Error fetching corporation killmails: #{inspect(error)}")
      {:error, "Failed to fetch killmail data"}
  end

  defp extract_corporation_members(killmails, corporation_id) do
    members =
      killmails
      |> Enum.flat_map(fn killmail ->
        Enum.filter(killmail.participants || [], &(&1.corporation_id == corporation_id))
      end)
      |> Enum.group_by(& &1.character_id)
      |> Enum.map(fn {character_id, participations} ->
        participation_damages = Enum.map(participations, &(&1.damage_done || 0))
        ship_type_ids = Enum.map(participations, & &1.ship_type_id)
        participation_times = Enum.map(participations, & &1.killmail_time)

        %{
          character_id: character_id,
          participation_count: length(participations),
          total_damage: Enum.sum(participation_damages),
          ship_types: Enum.uniq(ship_type_ids),
          first_seen: Enum.min(participation_times),
          last_seen: Enum.max(participation_times)
        }
      end)

    if Enum.empty?(members) do
      {:error, "No active members found for corporation"}
    else
      {:ok, members}
    end
  rescue
    error ->
      Logger.error("Error extracting corporation members: #{inspect(error)}")
      {:error, "Failed to extract member data"}
  end

  defp perform_corporation_analysis(members, corporation_id) when is_list(members) do
    analysis = %{
      corporation_id: corporation_id,
      member_count: length(members),
      member_correlations: analyze_member_correlations(members),
      activity_patterns: analyze_activity_patterns(members),
      risk_distribution: analyze_risk_distribution(members),
      coordination_analysis: analyze_coordination(members),
      analysis_timestamp: DateTime.utc_now(),
      confidence_score: calculate_analysis_confidence(members)
    }

    {:ok, analysis}
  rescue
    error ->
      Logger.error("Error in corporation analysis calculation: #{inspect(error)}")
      {:error, "Analysis calculation failed"}
  end

  defp analyze_shared_operations(members) do
    # Simplified shared operations analysis
    total_operations = Enum.sum(Enum.map(members, & &1.participation_count))
    shared_operations = if total_operations > 0, do: total_operations / length(members), else: 0

    %{
      average_shared_ops: shared_operations,
      coordination_indicator: if(shared_operations > 5, do: :high, else: :low)
    }
  end

  defp analyze_loss_distribution(members) do
    # Simplified loss distribution analysis
    high_activity_members = Enum.count(members, &(&1.participation_count > 10))

    %{
      high_activity_ratio: high_activity_members / length(members),
      distribution_pattern:
        if(high_activity_members > length(members) * 0.3, do: :concentrated, else: :distributed)
    }
  end

  defp calculate_activity_correlation(members) do
    # Simplified activity correlation
    avg_participation = Enum.sum(Enum.map(members, & &1.participation_count)) / length(members)

    %{
      average_participation: avg_participation,
      correlation_strength: if(avg_participation > 5, do: :strong, else: :weak)
    }
  end

  defp identify_primary_timezones(members) do
    # Analyze killmail times to identify primary timezone activity
    # Group activity by hour to find peak times
    activity_by_hour = analyze_hourly_activity_distribution(members)

    # Identify timezone peaks based on activity patterns
    # EU Prime: 19:00-23:00 UTC
    # US East Prime: 00:00-04:00 UTC (19:00-23:00 EST)
    # US West Prime: 03:00-07:00 UTC (19:00-23:00 PST)
    # AU Prime: 09:00-13:00 UTC (19:00-23:00 AEST)

    timezone_activity = %{
      eu: calculate_timezone_activity(activity_by_hour, 19..23),
      us_east: calculate_timezone_activity(activity_by_hour, 0..4),
      us_west: calculate_timezone_activity(activity_by_hour, 3..7),
      au: calculate_timezone_activity(activity_by_hour, 9..13)
    }

    total_activity = Enum.sum(Map.values(timezone_activity))

    if total_activity == 0 do
      %{primary_tz: "Unknown", coverage: "Insufficient data", distribution: %{}}
    else
      primary_tz =
        timezone_activity
        |> Enum.max_by(fn {_tz, activity} -> activity end)
        |> elem(0)
        |> format_timezone_name()

      coverage = calculate_coverage(activity_by_hour)

      distribution =
        Map.new(timezone_activity, fn {tz, activity} ->
          {format_timezone_name(tz), Float.round(activity / total_activity * 100, 1)}
        end)

      %{
        primary_tz: primary_tz,
        coverage: coverage,
        distribution: distribution,
        hourly_activity: activity_by_hour
      }
    end
  end

  defp analyze_hourly_activity_distribution(members) do
    # Analyze when members were active based on their participation times
    members
    |> Enum.flat_map(fn member ->
      # Get hour from first and last seen times
      hours = []
      hours = if member.first_seen, do: [member.first_seen.hour | hours], else: hours
      hours = if member.last_seen, do: [member.last_seen.hour | hours], else: hours
      hours
    end)
    |> Enum.frequencies()
    |> Map.new(fn {hour, count} -> {hour, count} end)
  end

  defp calculate_timezone_activity(activity_by_hour, hour_range) do
    hour_range
    |> Enum.map(fn hour -> Map.get(activity_by_hour, rem(hour, 24), 0) end)
    |> Enum.sum()
  end

  defp format_timezone_name(tz) do
    case tz do
      :eu -> "EU"
      :us_east -> "US-East"
      :us_west -> "US-West"
      :au -> "AU"
      _ -> "Unknown"
    end
  end

  defp calculate_coverage(activity_by_hour) do
    active_hours = Enum.count(activity_by_hour, fn {_hour, count} -> count > 0 end)

    cond do
      active_hours >= 20 -> "24/7 coverage"
      active_hours >= 16 -> "Good coverage (#{active_hours}h)"
      active_hours >= 12 -> "Moderate coverage (#{active_hours}h)"
      active_hours >= 8 -> "Limited coverage (#{active_hours}h)"
      true -> "Minimal coverage (#{active_hours}h)"
    end
  end

  defp categorize_engagement_types(members) do
    # Analyze engagement types based on member participation patterns
    total_participations = Enum.sum(Enum.map(members, & &1.participation_count))

    if total_participations == 0 do
      %{primary_type: "no_activity", secondary_type: "none"}
    else
      # Analyze ship types to determine engagement preferences
      ship_type_frequencies =
        members
        |> Enum.flat_map(& &1.ship_types)
        |> Enum.frequencies()

      # Categorize based on ship usage patterns
      engagement_categories = categorize_by_ship_types(ship_type_frequencies)

      sorted_categories =
        engagement_categories
        |> Enum.sort_by(fn {_type, count} -> count end, :desc)

      primary = sorted_categories |> List.first() |> elem(0)
      secondary = sorted_categories |> Enum.at(1, {:none, 0}) |> elem(0)

      %{
        primary_type: primary,
        secondary_type: secondary,
        breakdown:
          Map.new(engagement_categories, fn {type, count} ->
            {type, Float.round(count / total_participations * 100, 1)}
          end)
      }
    end
  end

  defp categorize_by_ship_types(ship_frequencies) do
    # Group ship types into engagement categories
    # This is simplified - in production would use actual ship type data
    pvp_ships = Map.get(ship_frequencies, :pvp_ships, 0)
    pve_ships = Map.get(ship_frequencies, :pve_ships, 0)
    logistics = Map.get(ship_frequencies, :logistics, 0)
    ewar = Map.get(ship_frequencies, :ewar, 0)

    %{
      pvp: pvp_ships,
      pve: pve_ships,
      support: logistics + ewar,
      mixed: Map.get(ship_frequencies, :mixed, length(Map.keys(ship_frequencies)))
    }
  end

  defp determine_operational_focus(members) do
    # Analyze operational focus based on activity patterns
    total_damage = Enum.sum(Enum.map(members, & &1.total_damage))

    avg_participation =
      Enum.sum(Enum.map(members, & &1.participation_count)) / max(length(members), 1)

    # Determine focus based on activity metrics
    focus =
      cond do
        avg_participation > 20 -> "heavy_pvp"
        avg_participation > 10 -> "active_pvp"
        avg_participation > 5 -> "moderate_activity"
        avg_participation > 2 -> "casual"
        true -> "minimal_activity"
      end

    # Determine secondary focus based on damage patterns
    damage_per_member = total_damage / max(length(members), 1)

    secondary_focus =
      cond do
        damage_per_member > 1_000_000_000 -> "capital_warfare"
        damage_per_member > 100_000_000 -> "fleet_operations"
        damage_per_member > 10_000_000 -> "small_gang"
        damage_per_member > 1_000_000 -> "solo_operations"
        true -> "minimal_combat"
      end

    %{
      focus: focus,
      secondary_focus: secondary_focus,
      metrics: %{
        avg_participation: Float.round(avg_participation, 1),
        damage_per_member: damage_per_member,
        total_members: length(members)
      }
    }
  end

  defp calculate_member_risk(member) do
    # Calculate risk based on actual member data
    # Base risk on kill/death ratio and PvP activity
    kills = Map.get(member, :recent_kills, 0)
    deaths = Map.get(member, :recent_deaths, 0)

    # Higher kills = higher risk, more deaths = lower risk
    base_risk =
      if deaths > 0 do
        min(100, kills / deaths * 25)
      else
        min(100, kills * 5)
      end

    round(base_risk)
  end

  defp calculate_variance(values) do
    if Enum.empty?(values) do
      0
    else
      mean = Enum.sum(values) / length(values)
      variance = Enum.sum(Enum.map(values, &:math.pow(&1 - mean, 2))) / length(values)
      variance
    end
  end

  defp categorize_risk_levels(risk_scores) do
    %{
      low: Enum.count(risk_scores, &(&1 < 30)),
      medium: Enum.count(risk_scores, &(&1 >= 30 and &1 <= 70)),
      high: Enum.count(risk_scores, &(&1 > 70))
    }
  end

  defp calculate_coordination_score(members) do
    # Simplified coordination calculation
    avg_ship_diversity =
      members
      |> Enum.map(&length(&1.ship_types))
      |> Enum.sum()
      |> Kernel./(length(members))

    # Higher diversity might indicate better coordination
    min(100, round(avg_ship_diversity * 10))
  end

  defp analyze_fleet_participation(members) do
    high_participation = Enum.count(members, &(&1.participation_count > 5))

    %{
      high_participation_ratio: high_participation / length(members),
      fleet_readiness: if(high_participation > length(members) * 0.5, do: :high, else: :moderate)
    }
  end

  defp measure_operational_synergy(members) do
    # Measure actual synergy based on member coordination patterns
    if length(members) < 2 do
      %{synergy_score: 0, synergy_level: :none}
    else
      # Calculate synergy metrics
      participation_variance = calculate_participation_variance(members)
      damage_distribution = calculate_damage_distribution(members)
      temporal_coordination = calculate_temporal_coordination(members)

      # Lower variance = better coordination
      participation_score = max(0, 100 - participation_variance * 10)

      # More even damage distribution = better teamwork
      damage_score = calculate_damage_evenness_score(damage_distribution)

      # Tighter temporal clustering = better coordination
      temporal_score = temporal_coordination * 100

      # Calculate overall synergy score
      synergy_score =
        (participation_score * 0.3 + damage_score * 0.4 + temporal_score * 0.3)
        |> Float.round(1)
        |> min(100)
        |> max(0)

      synergy_level =
        cond do
          synergy_score >= 80 -> :excellent
          synergy_score >= 60 -> :good
          synergy_score >= 40 -> :moderate
          synergy_score >= 20 -> :poor
          true -> :minimal
        end

      %{
        synergy_score: synergy_score,
        synergy_level: synergy_level,
        components: %{
          participation: Float.round(participation_score, 1),
          damage_distribution: Float.round(damage_score, 1),
          temporal_coordination: Float.round(temporal_score, 1)
        }
      }
    end
  end

  defp calculate_participation_variance(members) do
    participations = Enum.map(members, & &1.participation_count)
    calculate_variance(participations)
  end

  defp calculate_damage_distribution(members) do
    damages = Enum.map(members, & &1.total_damage)
    total = Enum.sum(damages)

    if total == 0 do
      %{gini_coefficient: 0, evenness: 0}
    else
      # Calculate Gini coefficient for damage distribution
      sorted = Enum.sort(damages)
      n = length(sorted)

      gini =
        if n == 0 do
          0
        else
          cumsum =
            Enum.reduce(sorted, {0, []}, fn x, {sum, acc} ->
              new_sum = sum + x
              {new_sum, acc ++ [new_sum]}
            end)
            |> elem(1)

          gini_sum = Enum.sum(cumsum)
          2 * gini_sum / (n * total) - (n + 1) / n
        end

      %{gini_coefficient: gini, evenness: 1 - gini}
    end
  end

  defp calculate_damage_evenness_score(distribution) do
    # Convert evenness to a score (0-100)
    (distribution.evenness * 100) |> Float.round(1)
  end

  defp calculate_temporal_coordination(members) do
    # Analyze how closely members operate together in time
    times =
      members
      |> Enum.flat_map(fn m ->
        times = []
        times = if m.first_seen, do: [DateTime.to_unix(m.first_seen) | times], else: times
        times = if m.last_seen, do: [DateTime.to_unix(m.last_seen) | times], else: times
        times
      end)

    if length(times) < 2 do
      0.0
    else
      # Calculate temporal clustering coefficient
      sorted_times = Enum.sort(times)

      gaps =
        sorted_times
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map(fn [a, b] -> b - a end)

      if Enum.empty?(gaps) do
        1.0
      else
        avg_gap = Enum.sum(gaps) / length(gaps)
        # Normalize: smaller gaps = better coordination
        # 1 hour gap = perfect, 24 hour gap = poor
        coordination = max(0, min(1, 1 - avg_gap / 86_400))
        Float.round(coordination, 3)
      end
    end
  end

  defp calculate_analysis_confidence(members) do
    # Base confidence on data quality and quantity
    base_confidence = min(90, length(members) * 5)
    total_participation = Enum.sum(Enum.map(members, & &1.participation_count))

    # Adjust based on activity level
    activity_bonus = min(10, total_participation)

    base_confidence + activity_bonus
  end

  defp perform_minimal_analysis(corporation_id) do
    {:ok,
     %{
       corporation_id: corporation_id,
       member_count: 0,
       member_correlations: %{
         shared_operations: %{average_shared_ops: 0, coordination_indicator: :unknown},
         loss_distribution: %{high_activity_ratio: 0, distribution_pattern: :unknown},
         activity_correlation: %{average_participation: 0, correlation_strength: :unknown}
       },
       activity_patterns: %{
         primary_timezones: %{primary_tz: "Unknown", coverage: "No data", distribution: %{}},
         engagement_types: %{primary_type: "no_activity", secondary_type: "none"},
         operational_focus: %{focus: "no_data", secondary_focus: "no_data", metrics: %{}}
       },
       risk_distribution: %{
         average_risk: 0,
         risk_variance: 0,
         high_risk_count: 0,
         risk_distribution: %{low: 0, medium: 0, high: 0}
       },
       coordination_analysis: %{
         coordination_score: 0,
         fleet_participation: %{high_participation_ratio: 0, fleet_readiness: :unknown},
         operational_synergy: %{synergy_score: 0, synergy_level: :none}
       },
       analysis_timestamp: DateTime.utc_now(),
       confidence_score: 0.0
     }}
  end
end
