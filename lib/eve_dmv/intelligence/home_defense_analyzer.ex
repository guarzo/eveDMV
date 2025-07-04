defmodule EveDmv.Intelligence.HomeDefenseAnalyzer do
  @moduledoc """
  Analyzes wormhole corporation home defense capabilities.

  Provides comprehensive analysis of timezone coverage, member activity patterns,
  rage rolling participation, response times, and overall defensive readiness.
  """

  require Logger
  alias EveDmv.Api
  alias EveDmv.Database.QueryUtils
  alias EveDmv.Eve.EsiUtils
  alias EveDmv.Intelligence.HomeDefenseAnalytics
  alias EveDmv.Killmails.KillmailEnriched
  require Ash.Query

  @doc """
  Perform comprehensive home defense analysis for a corporation.

  Returns {:ok, analytics_record} or {:error, reason}
  """
  def analyze_corporation(corporation_id, options \\ []) do
    with {:ok, analysis_config} <- setup_analysis_configuration(corporation_id, options),
         {:ok, raw_data} <- collect_analysis_data(analysis_config),
         {:ok, processed_data} <- process_analysis_data(raw_data),
         {:ok, analytics_record} <- persist_analysis_results(corporation_id, processed_data) do
      {:ok, analytics_record}
    else
      {:error, reason} -> handle_analysis_error(corporation_id, reason)
    end
  end

  defp setup_analysis_configuration(corporation_id, options) do
    Logger.info("Starting home defense analysis for corporation #{corporation_id}")

    period_days = Keyword.get(options, :period_days, 90)
    {start_date, end_date} = QueryUtils.calculate_precise_date_range(period_days)
    requested_by = Keyword.get(options, :requested_by)

    {:ok,
     %{
       corporation_id: corporation_id,
       start_date: start_date,
       end_date: end_date,
       requested_by: requested_by
     }}
  end

  defp collect_analysis_data(config) do
    with {:ok, corp_info} <- get_corporation_info(config.corporation_id),
         {:ok, members} <- get_corporation_members(config.corporation_id),
         {:ok, timezone_coverage} <-
           analyze_timezone_coverage(members, config.start_date, config.end_date),
         {:ok, rolling_participation} <-
           analyze_rolling_participation(
             config.corporation_id,
             config.start_date,
             config.end_date
           ),
         {:ok, response_metrics} <-
           analyze_response_metrics(config.corporation_id, config.start_date, config.end_date),
         {:ok, member_activity_patterns} <-
           analyze_member_activity_patterns(members, config.start_date, config.end_date),
         {:ok, defensive_capabilities} <-
           analyze_defensive_capabilities(config.corporation_id, members),
         {:ok, coverage_gaps} <-
           identify_coverage_gaps(timezone_coverage, response_metrics, member_activity_patterns) do
      {:ok,
       %{
         corp_info: corp_info,
         members: members,
         timezone_coverage: timezone_coverage,
         rolling_participation: rolling_participation,
         response_metrics: response_metrics,
         member_activity_patterns: member_activity_patterns,
         defensive_capabilities: defensive_capabilities,
         coverage_gaps: coverage_gaps,
         config: config
       }}
    end
  end

  defp process_analysis_data(raw_data) do
    scores =
      calculate_defense_scores(
        raw_data.timezone_coverage,
        raw_data.rolling_participation,
        raw_data.response_metrics,
        raw_data.member_activity_patterns,
        raw_data.defensive_capabilities
      )

    analytics_data = build_analytics_data(raw_data, scores)
    {:ok, analytics_data}
  end

  defp build_analytics_data(raw_data, scores) do
    %{
      corporation_id: raw_data.config.corporation_id,
      corporation_name: raw_data.corp_info.corporation_name,
      alliance_id: raw_data.corp_info.alliance_id,
      alliance_name: raw_data.corp_info.alliance_name,
      home_system_id: raw_data.corp_info.home_system_id,
      home_system_name: raw_data.corp_info.home_system_name,
      analysis_period_start: raw_data.config.start_date,
      analysis_period_end: raw_data.config.end_date,
      analysis_requested_by: raw_data.config.requested_by,
      overall_defense_score: scores.overall_defense_score,
      timezone_coverage_score: scores.timezone_coverage_score,
      response_time_score: scores.response_time_score,
      rolling_competency_score: scores.rolling_competency_score,
      member_participation_score: scores.member_participation_score,
      timezone_coverage: raw_data.timezone_coverage,
      rolling_participation: raw_data.rolling_participation,
      response_metrics: raw_data.response_metrics,
      member_activity_patterns: raw_data.member_activity_patterns,
      defensive_capabilities: raw_data.defensive_capabilities,
      coverage_gaps: raw_data.coverage_gaps,
      total_members_analyzed: length(raw_data.members),
      active_members_count: count_active_members(raw_data.members),
      critical_gaps_count: count_critical_gaps(raw_data.coverage_gaps),
      data_completeness_percent:
        calculate_data_completeness([
          raw_data.timezone_coverage,
          raw_data.rolling_participation,
          raw_data.response_metrics
        ])
    }
  end

  defp persist_analysis_results(corporation_id, analytics_data) do
    case HomeDefenseAnalytics.get_by_corporation(corporation_id) do
      {:ok, [existing]} ->
        HomeDefenseAnalytics.update_analysis(existing, analytics_data)

      {:ok, []} ->
        HomeDefenseAnalytics.create(analytics_data)

      {:error, _} ->
        HomeDefenseAnalytics.create(analytics_data)
    end
  end

  defp handle_analysis_error(corporation_id, reason) do
    Logger.error(
      "Home defense analysis failed for corporation #{corporation_id}: #{inspect(reason)}"
    )

    {:error, reason}
  end

  # Corporation information retrieval
  defp get_corporation_info(nil), do: {:error, "Invalid corporation ID"}

  defp get_corporation_info(corporation_id) do
    # Use the consolidated EsiUtils for better error handling
    # This function always returns {:ok, data} with fallback values
    {:ok, corp_data} = EsiUtils.fetch_corporation_with_alliance(corporation_id)

    # Check if we got fallback data
    if corp_data.corporation_name == "Unknown Corporation" do
      Logger.warning("Got fallback data for corporation #{corporation_id}")
    end

    {:ok,
     %{
       corporation_name: corp_data.corporation_name,
       alliance_id: corp_data.alliance_id,
       alliance_name: corp_data.alliance_name,
       # Home system would need to be configured elsewhere, as ESI doesn't provide this directly
       home_system_id: corp_data.corporation_id || 31_000_142,
       # This would need a mapping or configuration
       home_system_name: "J123456"
     }}
  end

  # Get corporation members
  defp get_corporation_members(corporation_id) do
    # First filter character stats at database level, not in memory
    case QueryUtils.query_corporation_members(corporation_id) do
      {:ok, corp_stats} ->
        process_corporation_stats(corp_stats)

      {:error, reason} ->
        Logger.warning(
          "Could not load character stats for corporation #{corporation_id}: #{inspect(reason)}"
        )

        {:ok, []}
    end
  rescue
    error ->
      Logger.error("Error getting corporation members: #{inspect(error)}")
      {:ok, []}
  end

  defp process_corporation_stats([]), do: {:ok, []}

  defp process_corporation_stats(corp_stats) do
    # Bulk update character info if needed
    character_ids = Enum.map(corp_stats, & &1.character_id)

    case EsiUtils.fetch_characters_bulk(character_ids) do
      {:ok, character_data} ->
        members = Enum.map(corp_stats, &update_member_with_character_data(&1, character_data))
        {:ok, members}

      {:error, reason} ->
        Logger.warning(
          "Failed to fetch character data, using stats without ESI enrichment: #{inspect(reason)}"
        )

        # Return corp_stats without ESI enrichment rather than failing
        {:ok, corp_stats}
    end
  end

  defp update_member_with_character_data(stats, character_data) do
    case Map.get(character_data, stats.character_id) do
      %{} = char_data ->
        %{
          stats
          | character_name: char_data.name,
            corporation_id: char_data.corporation_id,
            alliance_id: char_data.alliance_id
        }

      _ ->
        stats
    end
  end

  # Timezone coverage analysis
  defp analyze_timezone_coverage(members, _start_date, _end_date) do
    # Analyze member activity patterns across 24-hour period
    coverage_by_hour = generate_hourly_coverage(members)
    timezone_distribution = calculate_timezone_distribution(members)
    critical_gaps = identify_timezone_gaps(coverage_by_hour)
    peak_strength_hours = identify_peak_hours(coverage_by_hour)

    coverage = %{
      "coverage_by_hour" => coverage_by_hour,
      "timezone_distribution" => timezone_distribution,
      "critical_gaps" => critical_gaps,
      "peak_strength_hours" => peak_strength_hours
    }

    {:ok, coverage}
  end

  # Rolling participation analysis
  defp analyze_rolling_participation(corporation_id, start_date, end_date) do
    # Get actual rolling operations from killmail data
    {:ok, rolling_systems} = get_rolling_systems(corporation_id, start_date, end_date)

    participation = %{
      "total_rolling_ops" => length(rolling_systems),
      "member_participation" => calculate_member_rolling_participation(rolling_systems),
      "rolling_efficiency" => calculate_rolling_efficiency(rolling_systems),
      "success_rate" => calculate_rolling_success_rate(rolling_systems),
      "hole_types_rolled" => categorize_rolled_systems(rolling_systems)
    }

    {:ok, participation}
  end

  defp get_rolling_systems(corporation_id, start_date, end_date) do
    # Query killmails in wormhole systems where corporation members were active
    # Look for patterns indicating rolling operations:
    # - Multiple jumps through same connection
    # - Ships typically used for rolling (heavy ships, carriers)
    # - Time patterns suggesting coordinated rolling

    case QueryUtils.query_killmails_by_corporation(corporation_id, start_date, end_date) do
      {:ok, killmails} ->
        rolling_systems =
          killmails
          |> QueryUtils.filter_wormhole_killmails()
          |> group_by_system_and_time()
          |> identify_rolling_patterns()

        {:ok, rolling_systems}

      {:error, reason} ->
        Logger.warning("Failed to fetch killmails for rolling analysis: #{inspect(reason)}")
        {:ok, []}
    end
  end

  defp group_by_system_and_time(killmails) do
    # Group killmails by system and time windows to identify rolling operations
    killmails
    |> Enum.group_by(& &1.solar_system_id)
    |> Enum.map(fn {system_id, system_killmails} ->
      # Group by hour to find activity spikes
      hourly_groups =
        system_killmails
        |> Enum.group_by(fn km ->
          %{km.killmail_time | minute: 0, second: 0, microsecond: {0, 6}}
        end)

      %{
        system_id: system_id,
        activity_windows: hourly_groups,
        total_activity: length(system_killmails)
      }
    end)
  end

  defp identify_rolling_patterns(system_groups) do
    # Identify patterns that suggest rolling operations
    Enum.filter(system_groups, fn group ->
      # Look for:
      # 1. Multiple activity windows (suggesting repeated rolling)
      # 2. High activity density in short time periods
      # 3. Involvement of rolling-capable ships

      activity_windows = map_size(group.activity_windows)

      max_hourly_activity =
        group.activity_windows
        |> Map.values()
        |> Enum.map(&length/1)
        |> Enum.max(fn -> 0 end)

      # Consider it a rolling operation if:
      # - Multiple time windows of activity OR
      # - High activity density (5+ kills in one hour)
      activity_windows >= 2 or max_hourly_activity >= 5
    end)
  end

  defp calculate_member_rolling_participation(rolling_systems) do
    # Calculate individual member participation in rolling ops
    all_participants =
      rolling_systems
      |> Enum.flat_map(fn system ->
        system.activity_windows
        |> Map.values()
        |> List.flatten()
        |> Enum.flat_map(&(&1.participants || []))
      end)

    participation_counts =
      all_participants
      |> Enum.group_by(& &1.character_id)
      |> Enum.map(fn {char_id, participations} ->
        char_name = List.first(participations).character_name || "Unknown"

        %{
          character_id: char_id,
          character_name: char_name,
          rolling_ops_participated: length(participations)
        }
      end)
      |> Enum.sort_by(& &1.rolling_ops_participated, :desc)

    %{
      "participants" => participation_counts,
      "total_participants" => length(participation_counts),
      "avg_participation_per_member" => calculate_avg_participation(participation_counts)
    }
  end

  defp calculate_rolling_efficiency(rolling_systems) do
    if Enum.empty?(rolling_systems) do
      %{
        "avg_time_per_hole" => 0.0,
        "success_rate" => 0.0,
        "incidents" => 0,
        "estimated_collateral_damage" => 0
      }
    else
      total_ops = length(rolling_systems)

      # Estimate efficiency metrics based on activity patterns
      avg_duration = estimate_average_rolling_duration(rolling_systems)
      incident_count = count_rolling_incidents(rolling_systems)
      collateral_damage = estimate_collateral_damage(rolling_systems)

      %{
        "avg_time_per_hole" => avg_duration,
        "success_rate" => calculate_success_rate_from_incidents(total_ops, incident_count),
        "incidents" => incident_count,
        "estimated_collateral_damage" => collateral_damage
      }
    end
  end

  defp calculate_rolling_success_rate(rolling_systems) do
    if Enum.empty?(rolling_systems) do
      0.0
    else
      # Success rate based on lack of incidents and consistent patterns
      incidents = count_rolling_incidents(rolling_systems)
      total_ops = length(rolling_systems)

      max(0.0, (total_ops - incidents) / total_ops)
    end
  end

  defp categorize_rolled_systems(rolling_systems) do
    # Categorize the types of holes that were rolled
    rolling_systems
    |> Enum.reduce(%{}, fn system, acc ->
      # Categorize by system activity level and patterns
      category = categorize_wormhole_system(system)
      Map.update(acc, category, 1, &(&1 + 1))
    end)
  end

  # Helper functions for rolling analysis

  defp calculate_avg_participation(participation_counts) do
    if Enum.empty?(participation_counts) do
      0.0
    else
      total = Enum.sum(Enum.map(participation_counts, & &1.rolling_ops_participated))
      total / length(participation_counts)
    end
  end

  defp estimate_average_rolling_duration(rolling_systems) do
    # Estimate duration based on time spread of activity
    durations =
      Enum.map(rolling_systems, fn system ->
        times =
          system.activity_windows
          |> Map.keys()
          |> Enum.sort()

        if length(times) >= 2 do
          first = List.first(times)
          last = List.last(times)
          DateTime.diff(last, first, :minute)
        else
          # Default estimate for single-window operations
          30
        end
      end)

    if Enum.empty?(durations) do
      0.0
    else
      Enum.sum(durations) / length(durations)
    end
  end

  defp count_rolling_incidents(rolling_systems) do
    # Count potential incidents based on unusual activity patterns
    Enum.count(rolling_systems, fn system ->
      # Look for signs of incidents:
      # - Very high activity in short time (suggests losses)
      # - Prolonged activity periods (suggests complications)

      max_hourly_activity =
        system.activity_windows
        |> Map.values()
        |> Enum.map(&length/1)
        |> Enum.max(fn -> 0 end)

      activity_spread = map_size(system.activity_windows)

      # Consider it an incident if high activity (10+ kills) in one hour
      # or activity spread over many hours (4+)
      max_hourly_activity >= 10 or activity_spread >= 4
    end)
  end

  defp estimate_collateral_damage(rolling_systems) do
    # Estimate ISK value of ships lost during rolling operations
    rolling_systems
    |> Enum.flat_map(fn system ->
      system.activity_windows
      |> Map.values()
      |> List.flatten()
    end)
    |> Enum.reduce(0, fn km, acc ->
      value = Decimal.to_integer(km.total_value || Decimal.new(0))
      acc + value
    end)
  end

  defp calculate_success_rate_from_incidents(total_ops, incident_count) do
    if total_ops == 0 do
      0.0
    else
      max(0.0, (total_ops - incident_count) / total_ops)
    end
  end

  defp categorize_wormhole_system(system) do
    # Categorize wormhole systems by activity level and type
    total_activity = system.total_activity

    cond do
      total_activity >= 20 -> "high_activity_hole"
      total_activity >= 10 -> "static_connection"
      total_activity >= 5 -> "wandering_hole"
      true -> "low_activity_hole"
    end
  end

  # Response metrics analysis
  defp analyze_response_metrics(corporation_id, start_date, end_date) do
    # Analyze response times to threats and home defense battles
    {:ok, home_system_battles} = get_home_system_battles(corporation_id, start_date, end_date)

    response_times = calculate_response_times(home_system_battles)
    defense_success_rate = calculate_defense_success_rate(home_system_battles)

    metrics = %{
      "threat_responses" => %{
        "avg_response_time_seconds" => response_times.avg_response_time,
        "fastest_response_seconds" => response_times.fastest,
        "slowest_response_seconds" => response_times.slowest,
        "response_rate" => response_times.response_rate
      },
      "home_defense_battles" => %{
        "total_defenses" => length(home_system_battles),
        "successful_defenses" => defense_success_rate.successful,
        "failed_defenses" => defense_success_rate.failed,
        "evaded_threats" => defense_success_rate.evaded,
        "success_rate" => defense_success_rate.success_rate
      },
      "escalation_patterns" => %{
        "batphone_calls" => 3,
        "alliance_support" => 2,
        "successful_escalations" => 4,
        "avg_escalation_time" => 360
      },
      "threat_types_faced" => categorize_threat_types(home_system_battles)
    }

    {:ok, metrics}
  end

  # Member activity patterns analysis
  defp analyze_member_activity_patterns(members, _start_date, _end_date) do
    active_members = Enum.filter(members, &member_active?/1)

    activity_by_timezone = calculate_activity_by_timezone(active_members)
    role_coverage = calculate_role_coverage(active_members)
    engagement_readiness = assess_engagement_readiness(active_members)

    patterns = %{
      "active_members" => length(active_members),
      "total_members" => length(members),
      "activity_by_timezone" => activity_by_timezone,
      "role_coverage" => role_coverage,
      "engagement_readiness" => engagement_readiness
    }

    {:ok, patterns}
  end

  # Defensive capabilities analysis
  defp analyze_defensive_capabilities(corporation_id, members) do
    fleet_compositions = analyze_fleet_doctrines(members)
    infrastructure = assess_infrastructure_strength(corporation_id)
    intel_network = evaluate_intel_capabilities(corporation_id)

    capabilities = %{
      "fleet_compositions" => fleet_compositions,
      "infrastructure" => infrastructure,
      "intel_network" => intel_network
    }

    {:ok, capabilities}
  end

  # Coverage gaps identification
  defp identify_coverage_gaps(timezone_coverage, response_metrics, member_activity_patterns) do
    critical_weaknesses =
      find_critical_weaknesses(timezone_coverage, response_metrics, member_activity_patterns)

    improvement_priorities = generate_improvement_priorities(timezone_coverage, response_metrics)
    threat_preparedness = assess_threat_preparedness(member_activity_patterns, response_metrics)

    gaps = %{
      "critical_weaknesses" => critical_weaknesses,
      "improvement_priorities" => improvement_priorities,
      "threat_preparedness" => threat_preparedness
    }

    {:ok, gaps}
  end

  # Helper functions for timezone coverage
  defp generate_hourly_coverage(members) do
    # Generate coverage statistics for each hour of the day
    0..23
    |> Enum.map(fn hour ->
      pilots_online = estimate_pilots_online_at_hour(members, hour)
      fc_available = has_fc_coverage_at_hour(members, hour)
      logi_available = has_logi_coverage_at_hour(members, hour)

      {Integer.to_string(hour),
       %{
         "pilots_online" => pilots_online,
         "fc_available" => fc_available,
         "logi_available" => logi_available
       }}
    end)
    |> Enum.into(%{})
  end

  defp calculate_timezone_distribution(members) do
    # Categorize members by timezone
    timezones = ["US_TZ", "EU_TZ", "AU_TZ"]

    timezones
    |> Enum.map(fn tz ->
      tz_members = filter_members_by_timezone(members, tz)
      active_members = Enum.filter(tz_members, &member_active?/1)

      {tz,
       %{
         "member_count" => length(tz_members),
         "active_count" => length(active_members)
       }}
    end)
    |> Enum.into(%{})
  end

  defp identify_timezone_gaps(coverage_by_hour) do
    # Find hours with critical coverage gaps
    coverage_by_hour
    |> Enum.filter(fn {_hour, data} ->
      data["pilots_online"] < 3 or not data["fc_available"]
    end)
    |> Enum.map(fn {hour, data} ->
      severity = if data["pilots_online"] < 2, do: "critical", else: "high"

      %{
        "hour" => hour,
        "pilots_online" => data["pilots_online"],
        "severity" => severity,
        "description" => describe_coverage_gap(data)
      }
    end)
  end

  defp identify_peak_hours(coverage_by_hour) do
    # Find hours with strongest coverage
    coverage_by_hour
    |> Enum.filter(fn {_hour, data} -> data["pilots_online"] >= 8 end)
    |> Enum.map(fn {hour, _data} -> String.to_integer(hour) end)
    |> Enum.sort()
  end

  # Helper functions for response metrics
  defp get_home_system_battles(corporation_id, start_date, end_date) do
    # Find corporation's home system(s) from activity patterns
    case identify_home_systems(corporation_id) do
      [] ->
        Logger.info("No home systems identified for corporation #{corporation_id}")
        {:ok, []}

      home_systems ->
        # Get battles in home systems
        battles =
          Enum.flat_map(home_systems, fn system_id ->
            query =
              KillmailEnriched
              |> Ash.Query.new()
              |> Ash.Query.load(:participants)
              |> Ash.Query.filter(solar_system_id == ^system_id)
              |> Ash.Query.filter(killmail_time >= ^start_date)
              |> Ash.Query.filter(killmail_time <= ^end_date)
              |> Ash.Query.filter(exists(participants, corporation_id == ^corporation_id))

            case Ash.read(query, domain: Api) do
              {:ok, killmails} ->
                killmails

              {:error, reason} ->
                Logger.warning(
                  "Failed to fetch home system battles for system #{system_id}: #{inspect(reason)}"
                )

                []
            end
          end)

        {:ok, battles}
    end
  end

  defp identify_home_systems(corporation_id) do
    # Analyze where corporation members are most active
    # Look for systems with high activity density
    # Consider docking/undocking patterns if available

    # Query recent activity to identify home systems
    cutoff_date = DateTime.add(DateTime.utc_now(), -90, :day)

    query =
      KillmailEnriched
      |> Ash.Query.new()
      |> Ash.Query.load(:participants)
      |> Ash.Query.filter(killmail_time >= ^cutoff_date)
      |> Ash.Query.filter(exists(participants, corporation_id == ^corporation_id))

    case Ash.read(query, domain: Api) do
      {:ok, killmails} ->
        # Analyze activity patterns to identify home systems
        activity_by_system =
          killmails
          |> Enum.group_by(& &1.solar_system_id)
          |> Enum.map(fn {system_id, system_killmails} ->
            corp_participants =
              system_killmails
              |> Enum.flat_map(&(&1.participants || []))
              |> Enum.filter(&(&1.corporation_id == corporation_id))

            losses = Enum.count(corp_participants, &(&1.is_victim == true))
            kills = length(corp_participants) - losses

            defensive_ratio = if kills + losses > 0, do: losses / (kills + losses), else: 0

            %{
              system_id: system_id,
              frequency: length(system_killmails),
              defensive_ratio: defensive_ratio,
              corp_activity: length(corp_participants)
            }
          end)

        # Filter for likely home systems
        activity_by_system
        |> Enum.filter(fn activity ->
          # Home systems typically have:
          # - High activity frequency (10+ killmails)
          # - Significant defensive activity (20%+ losses)
          # - Regular corp member participation
          activity.frequency >= 10 and
            activity.defensive_ratio >= 0.2 and
            activity.corp_activity >= 5
        end)
        |> Enum.sort_by(& &1.frequency, :desc)
        # Top 3 most likely home systems
        |> Enum.take(3)
        |> Enum.map(& &1.system_id)

      {:error, reason} ->
        Logger.warning("Failed to identify home systems: #{inspect(reason)}")
        []
    end
  end

  defp calculate_response_times(battles) do
    response_times =
      Enum.map(battles, &calculate_battle_response_time/1)
      |> Enum.reject(&is_nil/1)

    if Enum.empty?(response_times) do
      %{
        avg_response_time: 0,
        fastest_response: 0,
        slowest_response: 0,
        response_rate: 0.0
      }
    else
      %{
        avg_response_time: Enum.sum(response_times) / length(response_times),
        fastest_response: Enum.min(response_times),
        slowest_response: Enum.max(response_times),
        response_rate: length(response_times) / length(battles)
      }
    end
  end

  defp calculate_battle_response_time(battle) do
    # Calculate time from first hostile contact to first defender response
    participants = battle.participants || []

    # Find hostile and friendly participants
    hostile_participants =
      Enum.reject(
        participants,
        &(&1.corporation_id == battle.participants |> List.first() |> Map.get(:corporation_id))
      )

    friendly_participants =
      Enum.filter(
        participants,
        &(&1.corporation_id == battle.participants |> List.first() |> Map.get(:corporation_id))
      )

    # For simplicity, we'll estimate response time based on attacker count
    # In a real implementation, we'd analyze damage timestamps
    attacker_count = length(hostile_participants)
    defender_count = length(friendly_participants)

    cond do
      # No response
      defender_count == 0 -> nil
      # Quick response to small threat
      attacker_count <= 2 and defender_count >= attacker_count -> 120
      # Moderate response
      attacker_count <= 5 and defender_count >= attacker_count / 2 -> 300
      # Slow response
      defender_count > 0 -> 600
      true -> nil
    end
  end

  defp calculate_defense_success_rate(battles) do
    # Calculate home defense success metrics
    # Placeholder implementation
    total = length(battles)

    %{
      successful: max(0, total - 2),
      failed: min(2, total),
      evaded: 0,
      success_rate: if(total > 0, do: (total - 2) / total, else: 0.0)
    }
  end

  defp categorize_threat_types(battles) do
    # Categorize threats by type and size based on actual battle data
    threat_counts =
      Enum.reduce(
        battles,
        %{
          "solo_hunters" => 0,
          "small_gangs" => 0,
          "eviction_scouts" => 0,
          "major_threats" => 0
        },
        fn battle, acc ->
          # Analyze each battle to categorize the threat
          attacker_count = length(battle.participants || [])

          attacker_corps =
            battle.participants
            |> Enum.map(& &1.corporation_id)
            |> Enum.uniq()
            |> length()

          threat_type =
            cond do
              # Solo hunter: 1 attacker
              attacker_count == 1 -> "solo_hunters"
              # Small gang: 2-5 attackers from same corp
              attacker_count <= 5 and attacker_corps <= 2 -> "small_gangs"
              # Major threat: 15+ attackers or multiple corps coordinating
              attacker_count >= 15 or attacker_corps >= 4 -> "major_threats"
              # Eviction scouts: Medium sized groups with certain ship types
              attacker_count <= 10 and has_scanning_ships?(battle) -> "eviction_scouts"
              # Default to small gang
              true -> "small_gangs"
            end

          Map.update!(acc, threat_type, &(&1 + 1))
        end
      )

    threat_counts
  end

  defp has_scanning_ships?(battle) do
    # Check if the battle involved typical scanning/scouting ships
    scanning_ships = ["Astero", "Stratios", "Buzzard", "Anathema", "Cheetah", "Helios"]

    battle.participants
    |> Enum.any?(fn participant ->
      ship_name = participant.ship_type_name || ""
      Enum.any?(scanning_ships, &String.contains?(ship_name, &1))
    end)
  end

  # Helper functions for member analysis
  defp member_active?(member) do
    # Determine if a member is considered active
    member.total_kills + member.total_losses > 5
  end

  defp estimate_pilots_online_at_hour(members, hour) do
    # Estimate how many pilots are typically online at a given hour
    # This would use actual activity data in production
    active_members = Enum.filter(members, &member_active?/1)

    case hour do
      # Prime time
      h when h in 18..23 -> round(length(active_members) * 0.6)
      # Afternoon
      h when h in 14..17 -> round(length(active_members) * 0.4)
      # Morning
      h when h in 6..13 -> round(length(active_members) * 0.3)
      # Off hours
      _ -> round(length(active_members) * 0.2)
    end
  end

  defp has_fc_coverage_at_hour(_members, hour) do
    # Determine if FC coverage exists at given hour
    # This would check actual FC availability
    # Simplified: assume FC coverage during prime time
    hour in 16..23
  end

  defp has_logi_coverage_at_hour(_members, hour) do
    # Determine if logistics coverage exists at given hour
    # Slightly broader than FC coverage
    hour in 15..24 or hour in 0..1
  end

  defp filter_members_by_timezone(members, timezone) do
    # Filter members by their primary timezone
    # This would use actual timezone data from EVE characters
    case timezone do
      "US_TZ" -> Enum.take(members, div(length(members), 2))
      "EU_TZ" -> Enum.take(members, div(length(members), 3))
      "AU_TZ" -> Enum.take(members, div(length(members), 5))
      _ -> []
    end
  end

  defp calculate_activity_by_timezone(members) do
    # Calculate activity statistics by timezone based on member activity patterns
    timezone_data = %{
      "US_TZ" => %{hours: 18..23, members: []},
      "EU_TZ" => %{hours: 14..17, members: []},
      "AU_TZ" => %{hours: 6..13, members: []}
    }

    # Group members by their primary timezone based on activity patterns
    members_by_tz =
      Enum.reduce(members, timezone_data, fn member, acc ->
        primary_tz = determine_member_timezone(member)
        update_in(acc[primary_tz][:members], &[member | &1])
      end)

    # Calculate statistics for each timezone
    Map.new(members_by_tz, fn {tz, data} ->
      tz_members = data.members
      member_count = length(tz_members)

      stats = %{
        "peak_online" => round(member_count * 0.8),
        "avg_online" => round(member_count * 0.6),
        "min_online" => round(member_count * 0.3)
      }

      {tz, stats}
    end)
  end

  defp determine_member_timezone(member) do
    # Determine member's primary timezone based on their activity patterns
    # This is a simplified heuristic - could be enhanced with more data
    total_activity = member.total_kills + member.total_losses

    cond do
      # High activity members more likely US TZ (largest EVE population)
      total_activity > 100 -> "US_TZ"
      # Medium activity could be EU
      total_activity > 30 -> "EU_TZ"
      # Lower activity could be AU/other
      true -> "AU_TZ"
    end
  end

  defp calculate_role_coverage(members) do
    # Calculate coverage by role type based on actual member capabilities
    active_members = Enum.filter(members, &member_active?/1)

    # Categorize members by their detected roles from ship usage
    role_groups =
      Enum.reduce(
        active_members,
        %{
          "fleet_commanders" => [],
          "logistics_pilots" => [],
          "tackle_specialists" => [],
          "dps_pilots" => []
        },
        fn member, acc ->
          member_roles = determine_member_roles(member)

          Enum.reduce(member_roles, acc, fn role, role_acc ->
            Map.update!(role_acc, role, &[member | &1])
          end)
        end
      )

    # Calculate statistics for each role
    Map.new(role_groups, fn {role, role_members} ->
      total_count = length(role_members)
      active_count = length(Enum.filter(role_members, &high_activity_member?/1))

      # Estimate coverage hours based on member count and activity
      coverage_hours =
        case total_count do
          0 -> 0
          count when count < 3 -> 8
          count when count < 6 -> 12
          count when count < 10 -> 16
          count when count < 15 -> 20
          _ -> 24
        end

      stats = %{
        "total" => total_count,
        "active" => active_count,
        "coverage_hours" => coverage_hours
      }

      {role, stats}
    end)
  end

  defp determine_member_roles(member) do
    # Determine member roles based on ship usage and stats
    roles = []
    ship_usage = member.ship_usage || %{}

    # FC detection - high kill count and leadership ships
    roles =
      if member.total_kills > 50 and has_command_ships?(ship_usage) do
        ["fleet_commanders" | roles]
      else
        roles
      end

    # Logistics detection
    roles =
      if has_logistics_ships?(ship_usage) do
        ["logistics_pilots" | roles]
      else
        roles
      end

    # Tackle detection
    roles =
      if has_tackle_ships?(ship_usage) do
        ["tackle_specialists" | roles]
      else
        roles
      end

    # DPS is default if no other specialized roles
    if Enum.empty?(roles) do
      ["dps_pilots"]
    else
      roles
    end
  end

  defp has_command_ships?(ship_usage) do
    command_ships = ["Command", "Fleet", "Wing", "Eos", "Claymore", "Damnation", "Nighthawk"]

    Enum.any?(ship_usage, fn {ship, _} ->
      Enum.any?(command_ships, &String.contains?(ship, &1))
    end)
  end

  defp has_logistics_ships?(ship_usage) do
    logi_ships = [
      "Scimitar",
      "Basilisk",
      "Guardian",
      "Oneiros",
      "Osprey",
      "Exequror",
      "Bantam",
      "Burst"
    ]

    Enum.any?(ship_usage, fn {ship, _} ->
      Enum.any?(logi_ships, &String.contains?(ship, &1))
    end)
  end

  defp has_tackle_ships?(ship_usage) do
    tackle_ships = [
      "Interceptor",
      "Dictor",
      "Hictor",
      "Sabre",
      "Devoter",
      "Onyx",
      "Broadsword",
      "Stiletto",
      "Crow",
      "Taranis"
    ]

    Enum.any?(ship_usage, fn {ship, _} ->
      Enum.any?(tackle_ships, &String.contains?(ship, &1))
    end)
  end

  defp high_activity_member?(member) do
    member.total_kills + member.total_losses > 25
  end

  defp assess_engagement_readiness(members) do
    # Assess how ready members are for combat
    total = length(members)

    %{
      "always_ready" => round(total * 0.15),
      "usually_ready" => round(total * 0.35),
      "sometimes_ready" => round(total * 0.30),
      "rarely_ready" => round(total * 0.20)
    }
  end

  # Helper functions for defensive capabilities
  defp analyze_fleet_doctrines(_members) do
    # Analyze available fleet compositions
    %{
      "home_defense_doctrine" => %{
        "ships" => ["Guardian", "Damnation", "Legion", "Cerberus"],
        "pilot_requirement" => 8,
        "effectiveness_rating" => 0.85
      },
      "rapid_response" => %{
        "ships" => ["Interceptor", "Assault Frigate", "Heavy Interdictor"],
        "pilot_requirement" => 3,
        "effectiveness_rating" => 0.92
      }
    }
  end

  defp assess_infrastructure_strength(_corporation_id) do
    # Assess defensive infrastructure
    %{
      "citadels" => 2,
      "weapon_timers" => 3,
      "tethering_points" => 6,
      "safe_spots" => 20
    }
  end

  defp evaluate_intel_capabilities(_corporation_id) do
    # Evaluate intelligence network capabilities
    %{
      "scout_coverage" => 0.75,
      "chain_monitoring" => true,
      "wanderer_integration" => true,
      "alert_systems" => ["discord", "in_game"]
    }
  end

  # Helper functions for coverage gaps
  defp find_critical_weaknesses(timezone_coverage, response_metrics, _member_activity_patterns) do
    weaknesses = []

    # Check for timezone gaps
    gaps = timezone_coverage["critical_gaps"] || []

    timezone_weaknesses =
      Enum.map(gaps, fn gap ->
        %{
          "type" => "timezone_gap",
          "description" => "Coverage gap at hour #{gap["hour"]}",
          "severity" => gap["severity"],
          "recommendation" => suggest_timezone_improvement(gap)
        }
      end)

    # Check for response time issues
    response_weaknesses =
      if response_metrics["threat_responses"]["avg_response_time_seconds"] > 300 do
        [
          %{
            "type" => "slow_response",
            "description" => "Response time exceeds 5 minutes",
            "severity" => "medium",
            "recommendation" => "Improve alert systems and pre-positioning"
          }
        ]
      else
        []
      end

    weaknesses ++ timezone_weaknesses ++ response_weaknesses
  end

  defp generate_improvement_priorities(timezone_coverage, _response_metrics) do
    # Generate prioritized improvement recommendations
    [
      %{
        "area" => "timezone_coverage",
        "current_score" => calculate_timezone_score(timezone_coverage),
        "target_score" => 85,
        "action_items" => ["Recruit timezone-specific pilots", "Improve shift scheduling"]
      }
    ]
  end

  defp assess_threat_preparedness(_member_activity_patterns, _response_metrics) do
    # Assess preparedness for different threat types
    %{
      "eviction_readiness" => 0.7,
      "small_gang_response" => 0.85,
      "solo_hunter_deterrence" => 0.9
    }
  end

  # Scoring calculations
  defp calculate_defense_scores(
         timezone_coverage,
         rolling_participation,
         response_metrics,
         member_activity_patterns,
         _defensive_capabilities
       ) do
    timezone_score = calculate_timezone_score(timezone_coverage)
    response_score = calculate_response_score(response_metrics)
    rolling_score = calculate_rolling_score(rolling_participation)
    participation_score = calculate_participation_score(member_activity_patterns)

    overall_score =
      calculate_overall_defense_score(
        timezone_score,
        response_score,
        rolling_score,
        participation_score
      )

    %{
      timezone_coverage_score: timezone_score,
      response_time_score: response_score,
      rolling_competency_score: rolling_score,
      member_participation_score: participation_score,
      overall_defense_score: overall_score
    }
  end

  defp calculate_timezone_score(timezone_coverage) do
    # Score based on timezone coverage quality
    gaps = length(timezone_coverage["critical_gaps"] || [])
    peak_hours = length(timezone_coverage["peak_strength_hours"] || [])

    base_score = 100
    gap_penalty = gaps * 15
    peak_bonus = min(20, peak_hours * 3)

    max(0, min(100, base_score - gap_penalty + peak_bonus))
  end

  defp calculate_response_score(response_metrics) do
    # Score based on response time and success rate
    threat_responses = response_metrics["threat_responses"] || %{}
    avg_response = threat_responses["avg_response_time_seconds"] || 300
    response_rate = threat_responses["response_rate"] || 0.5

    # Better score for faster response times
    time_score = max(0, 100 - (avg_response - 60) / 3)
    rate_score = response_rate * 100

    round((time_score + rate_score) / 2)
  end

  defp calculate_rolling_score(rolling_participation) do
    # Score based on rolling efficiency and participation
    efficiency = rolling_participation["rolling_efficiency"] || %{}
    success_rate = efficiency["success_rate"] || 0.5
    ops_count = rolling_participation["total_rolling_ops"] || 0

    base_score = success_rate * 80
    activity_bonus = min(20, ops_count)

    round(base_score + activity_bonus)
  end

  defp calculate_participation_score(member_activity_patterns) do
    # Score based on member participation rates
    active = member_activity_patterns["active_members"] || 0
    total = member_activity_patterns["total_members"] || 1

    round(QueryUtils.safe_percentage(active, total))
  end

  defp calculate_overall_defense_score(
         timezone_score,
         response_score,
         rolling_score,
         participation_score
       ) do
    # Weighted average of all scores
    weights = %{
      timezone: 0.3,
      response: 0.25,
      rolling: 0.2,
      participation: 0.25
    }

    weighted_score =
      timezone_score * weights.timezone +
        response_score * weights.response +
        rolling_score * weights.rolling +
        participation_score * weights.participation

    round(weighted_score)
  end

  # Utility functions
  defp describe_coverage_gap(data) do
    cond do
      not data["fc_available"] -> "No FC available"
      not data["logi_available"] -> "No logistics support"
      data["pilots_online"] < 3 -> "Insufficient pilot count"
      true -> "General coverage weakness"
    end
  end

  defp suggest_timezone_improvement(gap) do
    case gap["severity"] do
      "critical" -> "Urgent: Recruit pilots for this timezone"
      "high" -> "Recruit additional pilots or improve scheduling"
      _ -> "Consider coverage improvement"
    end
  end

  defp count_active_members(members) do
    Enum.count(members, &member_active?/1)
  end

  defp count_critical_gaps(coverage_gaps) do
    critical_weaknesses = coverage_gaps["critical_weaknesses"] || []
    Enum.count(critical_weaknesses, fn w -> w["severity"] in ["critical", "high"] end)
  end

  defp calculate_data_completeness(data_sections) do
    # Calculate percentage of data sections that have meaningful content
    non_empty_sections =
      Enum.count(data_sections, fn section ->
        case section do
          map when is_map(map) -> map_size(map) > 0
          _ -> false
        end
      end)

    round(non_empty_sections / length(data_sections) * 100)
  end

  # Public API functions expected by tests

  @doc """
  Calculate timezone coverage from member activity data.
  """
  def calculate_timezone_coverage(member_activities) when is_list(member_activities) do
    if Enum.empty?(member_activities) do
      %{
        coverage_score: 0,
        timezone_distribution: %{},
        weak_periods: [],
        peak_activity_times: []
      }
    else
      # Calculate coverage by hour
      hourly_coverage = calculate_hourly_coverage_from_activities(member_activities)

      # Distribution by timezone
      timezone_dist =
        member_activities
        |> Enum.group_by(& &1.timezone)
        |> Enum.map(fn {tz, members} -> {tz, length(members)} end)
        |> Enum.into(%{})

      # Find weak periods (hours with < 20% coverage)
      weak_periods = find_weak_periods(hourly_coverage)

      # Find peak activity times (hours with > 60% coverage)
      peak_times = find_peak_activity_times(hourly_coverage)

      # Calculate overall coverage score
      coverage_score = calculate_coverage_score_from_hourly(hourly_coverage)

      %{
        coverage_score: coverage_score,
        timezone_distribution: timezone_dist,
        weak_periods: weak_periods,
        peak_activity_times: peak_times
      }
    end
  end

  @doc """
  Assess fleet capabilities from member data.
  """
  def assess_fleet_capabilities(members) when is_list(members) do
    if Enum.empty?(members) do
      %{
        total_members: 0,
        doctrine_ships: %{},
        fc_count: 0,
        logistics_count: 0,
        capability_score: 0
      }
    else
      # Count FCs and logistics pilots
      fc_count = Enum.count(members, &Map.get(&1, :fc_capability, false))
      logi_count = Enum.count(members, &Map.get(&1, :logistics_capability, false))

      # Aggregate doctrine ships
      doctrine_ships = aggregate_doctrine_ships(members)

      # Calculate capability score
      capability_score = calculate_capability_score(members, fc_count, logi_count)

      %{
        total_members: length(members),
        doctrine_ships: doctrine_ships,
        fc_count: fc_count,
        logistics_count: logi_count,
        capability_score: capability_score
      }
    end
  end

  @doc """
  Calculate response readiness based on recent activity.
  """
  def calculate_response_readiness(members, current_time) when is_list(members) do
    # Count members with recent activity (within 12 hours)
    cutoff_time = DateTime.add(current_time, -12 * 60 * 60, :second)

    recent_members =
      Enum.filter(members, fn member ->
        case Map.get(member, :last_activity) do
          nil -> false
          last_activity -> DateTime.compare(last_activity, cutoff_time) != :lt
        end
      end)

    # Calculate average response time
    response_times = Enum.map(members, &Map.get(&1, :response_time_minutes, 60))

    avg_response_time =
      if Enum.empty?(response_times),
        do: 0,
        else: Enum.sum(response_times) / length(response_times)

    # Calculate readiness score
    immediate_response = length(recent_members)
    total_members = length(members)

    readiness_score =
      if total_members > 0 do
        base_score = immediate_response / total_members * 100
        # Bonus for fast response times
        response_bonus = max(0, (60 - avg_response_time) / 60 * 20)
        min(100, base_score + response_bonus)
      else
        0
      end

    %{
      immediate_response: immediate_response,
      avg_response_time: avg_response_time,
      readiness_score: round(readiness_score),
      available_members: recent_members
    }
  end

  @doc """
  Identify defense weaknesses from analysis data.
  """
  def identify_defense_weaknesses(analysis_data) do
    critical_weaknesses = []
    moderate_weaknesses = []
    suggestions = []

    # Check timezone coverage
    timezone_score = get_in(analysis_data, [:timezone_coverage, :coverage_score]) || 0
    _weak_periods = get_in(analysis_data, [:timezone_coverage, :weak_periods]) || []

    {critical, moderate, suggestions} =
      if timezone_score < 50 do
        weakness = %{
          type: "timezone_coverage",
          description: "Poor timezone coverage (#{timezone_score}%)",
          severity: if(timezone_score < 30, do: "critical", else: "moderate")
        }

        suggestion = "Recruit members in underrepresented timezones"

        if timezone_score < 30 do
          {[weakness | critical_weaknesses], moderate_weaknesses, [suggestion | suggestions]}
        else
          {critical_weaknesses, [weakness | moderate_weaknesses], [suggestion | suggestions]}
        end
      else
        {critical_weaknesses, moderate_weaknesses, suggestions}
      end

    # Check FC count
    fc_count = get_in(analysis_data, [:fleet_capabilities, :fc_count]) || 0

    {critical, moderate, suggestions} =
      if fc_count < 2 do
        weakness = %{
          type: "fc_shortage",
          description: "Insufficient fleet commanders (#{fc_count})",
          severity: if(fc_count == 0, do: "critical", else: "moderate")
        }

        suggestion = "Train additional fleet commanders"

        if fc_count == 0 do
          {[weakness | critical], moderate, [suggestion | suggestions]}
        else
          {critical, [weakness | moderate], [suggestion | suggestions]}
        end
      else
        {critical, moderate, suggestions}
      end

    # Check response readiness
    readiness_score = get_in(analysis_data, [:response_readiness, :readiness_score]) || 0

    {critical, moderate, suggestions} =
      if readiness_score < 40 do
        weakness = %{
          type: "response_readiness",
          description: "Poor response readiness (#{readiness_score}%)",
          severity: "moderate"
        }

        suggestion = "Improve member activity and response times"
        {critical, [weakness | moderate], [suggestion | suggestions]}
      else
        {critical, moderate, suggestions}
      end

    %{
      critical_weaknesses: critical,
      moderate_weaknesses: moderate,
      improvement_suggestions: suggestions
    }
  end

  @doc """
  Generate defense recommendations based on analysis.
  """
  def generate_defense_recommendations(analysis_data) do
    _defense_score = Map.get(analysis_data, :defense_score, 0)
    weaknesses = Map.get(analysis_data, :weaknesses, %{})

    _priority_actions = []
    _short_term_goals = []
    _long_term_strategy = []

    # Priority actions based on critical weaknesses
    critical_weaknesses = Map.get(weaknesses, :critical_weaknesses, [])

    priority_actions =
      Enum.map(critical_weaknesses, fn weakness ->
        case weakness.type do
          "timezone_gap" -> "Urgently recruit AUTZ/EUTZ/USTZ members"
          "fc_shortage" -> "Train emergency fleet commanders immediately"
          _ -> "Address critical #{weakness.type} issue"
        end
      end)

    # Short-term goals
    short_term_goals = [
      "Improve member activity tracking",
      "Establish doctrine ship requirements",
      "Create response time training"
    ]

    # Long-term strategy
    long_term_strategy = [
      "Develop comprehensive defense doctrine",
      "Build alliance-level support network",
      "Establish member progression pathways"
    ]

    # Resource requirements
    resource_requirements = %{
      "recruitment_priority" => determine_recruitment_priority(analysis_data),
      "training_hours_needed" => calculate_training_requirements(analysis_data),
      "isk_investment" => estimate_isk_requirements(analysis_data)
    }

    %{
      priority_actions: priority_actions,
      short_term_goals: short_term_goals,
      long_term_strategy: long_term_strategy,
      resource_requirements: resource_requirements
    }
  end

  @doc """
  Calculate overall defense score from analysis components.
  """
  def calculate_defense_score(analysis_components) do
    timezone_score = get_in(analysis_components, [:timezone_coverage, :coverage_score]) || 0
    capability_score = get_in(analysis_components, [:fleet_capabilities, :capability_score]) || 0
    readiness_score = get_in(analysis_components, [:response_readiness, :readiness_score]) || 0
    member_count = Map.get(analysis_components, :member_count, 0)
    activity_level = Map.get(analysis_components, :activity_level, 0)

    # Base score from weighted components
    base_score =
      timezone_score * 0.3 + capability_score * 0.25 + readiness_score * 0.25 +
        activity_level * 0.2

    # Member count modifier
    member_modifier =
      cond do
        member_count >= 20 -> 1.0
        member_count >= 10 -> 0.9
        member_count >= 5 -> 0.8
        member_count >= 3 -> 0.7
        true -> 0.5
      end

    final_score = base_score * member_modifier
    round(min(100, max(0, final_score)))
  end

  @doc """
  Format analysis into readable report.
  """
  def format_analysis_report(analysis) do
    defense_score = Map.get(analysis, :defense_score, 0)

    # Build the report components
    summary = build_executive_summary(defense_score)
    detailed_metrics = extract_detailed_metrics(analysis)
    recommendations = generate_recommendations(analysis)

    %{
      executive_summary: String.trim(summary),
      detailed_metrics: detailed_metrics,
      actionable_recommendations: recommendations
    }
  end

  defp build_executive_summary(defense_score) do
    assessment = get_defense_assessment(defense_score)

    """
    Defense Analysis Summary:
    Overall Defense Score: #{defense_score}/100

    This analysis evaluates the corporation's home defense capabilities across timezone coverage,
    fleet readiness, and response capabilities.
    #{assessment}
    """
  end

  defp get_defense_assessment(defense_score) do
    cond do
      defense_score >= 80 ->
        "The corporation shows excellent defensive preparedness."

      defense_score >= 60 ->
        "The corporation has good defensive capabilities with room for improvement."

      defense_score >= 40 ->
        "The corporation has moderate defensive capabilities requiring attention."

      true ->
        "The corporation has significant defensive weaknesses requiring immediate action."
    end
  end

  defp extract_detailed_metrics(analysis) do
    timezone_coverage = get_in(analysis, [:timezone_coverage, :coverage_score]) || 0
    fc_count = get_in(analysis, [:fleet_capabilities, :fc_count]) || 0
    logi_count = get_in(analysis, [:fleet_capabilities, :logistics_count]) || 0
    readiness_score = get_in(analysis, [:response_readiness, :readiness_score]) || 0

    %{
      "Timezone Coverage" => "#{timezone_coverage}%",
      "Fleet Commanders" => fc_count,
      "Logistics Pilots" => logi_count,
      "Response Readiness" => "#{readiness_score}%"
    }
  end

  defp generate_recommendations(analysis) do
    timezone_coverage = get_in(analysis, [:timezone_coverage, :coverage_score]) || 0
    fc_count = get_in(analysis, [:fleet_capabilities, :fc_count]) || 0
    readiness_score = get_in(analysis, [:response_readiness, :readiness_score]) || 0

    recommendations = []
    recommendations = add_timezone_recommendation(recommendations, timezone_coverage)
    recommendations = add_fc_recommendation(recommendations, fc_count)
    recommendations = add_readiness_recommendation(recommendations, readiness_score)

    if Enum.empty?(recommendations) do
      ["Maintain current defensive capabilities and continue monitoring"]
    else
      recommendations
    end
  end

  defp add_timezone_recommendation(recommendations, timezone_coverage)
       when timezone_coverage < 70 do
    ["Improve timezone coverage by recruiting in weak timezones" | recommendations]
  end

  defp add_timezone_recommendation(recommendations, _), do: recommendations

  defp add_fc_recommendation(recommendations, fc_count) when fc_count < 3 do
    ["Train additional fleet commanders" | recommendations]
  end

  defp add_fc_recommendation(recommendations, _), do: recommendations

  defp add_readiness_recommendation(recommendations, readiness_score) when readiness_score < 60 do
    ["Improve member activity and response training" | recommendations]
  end

  defp add_readiness_recommendation(recommendations, _), do: recommendations

  @doc """
  Classify timezone from timezone string.
  """
  def classify_timezone(timezone_string) do
    case timezone_string do
      tz when tz in ["UTC", "Europe/London", "Europe/Berlin", "Europe/Paris"] ->
        :eutz

      tz
      when tz in ["US/Eastern", "US/Central", "US/Mountain", "US/Pacific", "America/New_York"] ->
        :ustz

      tz when tz in ["Australia/Sydney", "Australia/Melbourne", "Pacific/Auckland"] ->
        :autz

      _ ->
        :unknown
    end
  end

  @doc """
  Calculate activity score based on last activity time.
  """
  def calculate_activity_score(last_activity, current_time) do
    hours_ago = DateTime.diff(current_time, last_activity, :hour)

    cond do
      hours_ago <= 1 -> 100
      hours_ago <= 6 -> 90
      hours_ago <= 24 -> 75
      hours_ago <= 72 -> 50
      # 1 week
      hours_ago <= 168 -> 25
      true -> 10
    end
  end

  @doc """
  Check if ship type is a doctrine ship.
  """
  def doctrine_ship?(ship_name) do
    doctrine_ships = [
      "Damnation",
      "Legion",
      "Guardian",
      "Muninn",
      "Scimitar",
      "Cerberus",
      "Basilisk",
      "Zealot",
      "Oneiros",
      "Hurricane",
      "Sleipnir",
      "Claymore",
      "Nighthawk"
    ]

    ship_name in doctrine_ships
  end

  @doc """
  Calculate coverage gap from active hours.
  """
  def calculate_coverage_gap(active_hours, total_hours \\ 24) do
    all_hours = 0..(total_hours - 1) |> Enum.to_list()
    uncovered_hours = all_hours -- active_hours

    # Find the longest consecutive gap
    max_gap = find_longest_consecutive_gap(uncovered_hours)

    %{
      max_gap_hours: max_gap,
      total_uncovered_hours: length(uncovered_hours),
      coverage_percentage: length(active_hours) / total_hours * 100
    }
  end

  @doc """
  Fetch member data for corporation.
  """
  def fetch_member_data(corporation_id) do
    case get_corporation_members(corporation_id) do
      {:ok, [_ | _] = members} ->
        processed_members =
          Enum.map(members, fn member ->
            %{
              character_id: member.character_id,
              character_name: member.character_name || "Unknown",
              last_activity: member.last_killmail_date,
              timezone: determine_member_timezone(member),
              activity_score: calculate_member_activity_score(member)
            }
          end)

        {:ok, processed_members}

      {:ok, []} ->
        {:error, :not_found}
    end
  end

  # Helper functions for new public API functions

  defp calculate_hourly_coverage_from_activities(member_activities) do
    0..23
    |> Enum.map(fn hour ->
      active_count =
        Enum.count(member_activities, fn member ->
          active_hours = Map.get(member, :active_hours, [])
          hour in active_hours
        end)

      {hour, active_count}
    end)
    |> Enum.into(%{})
  end

  defp find_weak_periods(hourly_coverage) do
    total_members = hourly_coverage |> Map.values() |> Enum.max(fn -> 1 end)
    # 20% threshold
    threshold = max(1, round(total_members * 0.2))

    hourly_coverage
    |> Enum.filter(fn {_hour, count} -> count < threshold end)
    |> Enum.map(fn {hour, count} ->
      %{
        start_hour: hour,
        end_hour: hour + 1,
        coverage: round(count / max(1, total_members) * 100)
      }
    end)
  end

  defp find_peak_activity_times(hourly_coverage) do
    total_members = hourly_coverage |> Map.values() |> Enum.max(fn -> 1 end)
    # 60% threshold
    threshold = max(1, round(total_members * 0.6))

    hourly_coverage
    |> Enum.filter(fn {_hour, count} -> count >= threshold end)
    |> Enum.map(fn {hour, _count} -> hour end)
  end

  defp calculate_coverage_score_from_hourly(hourly_coverage) do
    if map_size(hourly_coverage) == 0 do
      0
    else
      covered_hours = Enum.count(hourly_coverage, fn {_hour, count} -> count > 0 end)
      round(covered_hours / 24 * 100)
    end
  end

  defp aggregate_doctrine_ships(members) do
    members
    |> Enum.flat_map(fn member -> Map.get(member, :ship_types, []) end)
    |> Enum.filter(&doctrine_ship?/1)
    |> Enum.frequencies()
  end

  defp calculate_capability_score(members, fc_count, logi_count) do
    total = length(members)

    if total == 0 do
      0
    else
      # Base score from member count
      member_score = min(50, total * 2)

      # FC bonus (up to 25 points)
      fc_score = min(25, fc_count * 8)

      # Logistics bonus (up to 25 points)
      logi_score = min(25, logi_count * 5)

      member_score + fc_score + logi_score
    end
  end

  defp determine_recruitment_priority(analysis_data) do
    timezone_score = get_in(analysis_data, [:timezone_coverage, :coverage_score]) || 0

    cond do
      timezone_score < 30 -> "Critical - All timezones"
      timezone_score < 60 -> "High - Weak timezone focus"
      true -> "Moderate - Quality over quantity"
    end
  end

  defp calculate_training_requirements(analysis_data) do
    fc_count = get_in(analysis_data, [:fleet_capabilities, :fc_count]) || 0
    member_count = Map.get(analysis_data, :member_count, 0)

    # Base training hours needed
    # 20 hours per missing FC
    base_hours = max(0, (5 - fc_count) * 20)
    # 2 hours per member for general training
    member_hours = member_count * 2

    base_hours + member_hours
  end

  defp estimate_isk_requirements(analysis_data) do
    member_count = Map.get(analysis_data, :member_count, 0)

    # Rough estimate: 500M ISK per member for doctrine ships
    member_count * 500_000_000
  end

  defp find_longest_consecutive_gap(uncovered_hours) do
    if Enum.empty?(uncovered_hours) do
      0
    else
      uncovered_hours
      |> Enum.sort()
      |> Enum.chunk_while(
        [],
        fn hour, acc ->
          case acc do
            [] -> {:cont, [hour]}
            [last | _] when hour == last + 1 -> {:cont, [hour | acc]}
            _ -> {:halt, acc}
          end
        end,
        fn acc -> {:cont, acc, []} end
      )
      |> Enum.map(&length/1)
      |> Enum.max(fn -> 0 end)
    end
  end

  defp calculate_member_activity_score(member) do
    # Calculate activity score based on kills, losses, and recent activity
    total_activity = (member.total_kills || 0) + (member.total_losses || 0)

    base_score = min(80, total_activity * 2)

    # Recent activity bonus
    recent_bonus =
      case member.last_killmail_date do
        nil ->
          0

        last_date ->
          days_ago = DateTime.diff(DateTime.utc_now(), last_date, :day)
          max(0, 20 - days_ago)
      end

    min(100, base_score + recent_bonus)
  end
end
