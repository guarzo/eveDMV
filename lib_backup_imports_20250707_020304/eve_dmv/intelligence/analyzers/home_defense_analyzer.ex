defmodule EveDmv.Intelligence.Analyzers.HomeDefenseAnalyzer do
  alias EveDmv.Api
  alias EveDmv.Database.QueryUtils
  alias EveDmv.Intelligence.HomeDefenseAnalytics

  require Ash.Query
  require Logger
  @moduledoc """
  Simplified home defense analysis for wormhole corporations.

  Provides clear, focused analysis of timezone coverage, member activity,
  and defensive capabilities without over-engineering.
  """


  @doc """
  Analyze corporation home defense capabilities.

  Returns comprehensive analysis of defensive readiness and coverage patterns.
  """
  @spec analyze_corporation(integer(), keyword()) :: {:ok, map()} | {:error, String.t()}
  def analyze_corporation(corporation_id, options \\ []) do
    Logger.info("Starting home defense analysis for corporation #{corporation_id}")

    period_days = Keyword.get(options, :period_days, 90)
    end_date = DateTime.utc_now()
    start_date = DateTime.add(end_date, -period_days, :day)

    with {:ok, corp_info} <- get_corporation_info(corporation_id),
         {:ok, members} <- get_corporation_members(corporation_id),
         {:ok, killmails} <- get_corporation_killmails(corporation_id, start_date, end_date) do
      # Perform analysis
      timezone_coverage = analyze_timezone_coverage(members, killmails)
      rolling_participation = analyze_rolling_participation(killmails)
      response_metrics = analyze_response_metrics(killmails)
      defensive_capabilities = analyze_defensive_capabilities(members, killmails)

      # Calculate overall scores
      defense_score =
        calculate_defense_score(timezone_coverage, rolling_participation, response_metrics)

      coverage_gaps = identify_coverage_gaps(timezone_coverage, response_metrics)

      analysis = %{
        corporation_id: corporation_id,
        corporation_name: corp_info.name,
        analysis_period: %{start_date: start_date, end_date: end_date},
        defense_score: defense_score,
        timezone_coverage: timezone_coverage,
        rolling_participation: rolling_participation,
        response_metrics: response_metrics,
        defensive_capabilities: defensive_capabilities,
        coverage_gaps: coverage_gaps,
        member_count: length(members),
        analysis_timestamp: DateTime.utc_now()
      }

      # Save analysis results
      save_analysis_results(analysis)

      {:ok, analysis}
    else
      {:error, reason} ->
        Logger.error("Home defense analysis failed for corp #{corporation_id}: #{reason}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Unexpected error in home defense analysis: #{inspect(error)}")
      {:error, "Analysis failed due to unexpected error"}
  end

  @doc """
  Backward compatibility alias.
  """
  @spec analyze_home_defense(integer(), integer()) :: {:ok, map()} | {:error, String.t()}
  def analyze_home_defense(corporation_id, home_system_id) do
    analyze_corporation(corporation_id, home_system_id: home_system_id)
  end

  @doc """
  Analyze timezone coverage patterns from member activity.
  """
  @spec analyze_timezone_coverage(list(), list()) :: map()
  def analyze_timezone_coverage(_members, killmails) do
    if Enum.empty?(killmails) do
      %{
        coverage_score: 0,
        active_timezones: [],
        coverage_percentage: 0.0,
        peak_hours: [],
        coverage_gaps: []
      }
    else
      hourly_activity = calculate_hourly_activity(killmails)

      activity_keys = Map.keys(hourly_activity)
      active_hours = Enum.filter(activity_keys, &(Map.get(hourly_activity, &1, 0) > 0))

      %{
        coverage_score: calculate_coverage_score(active_hours),
        active_timezones: identify_active_timezones(active_hours),
        coverage_percentage: length(active_hours) / 24 * 100,
        peak_hours: identify_peak_hours(hourly_activity),
        coverage_gaps: identify_timezone_gaps(active_hours)
      }
    end
  end

  @doc """
  Analyze rolling (rage rolling) participation patterns.
  """
  @spec analyze_rolling_participation(list()) :: map()
  def analyze_rolling_participation(killmails) do
    rolling_indicators = identify_rolling_indicators(killmails)
    rolling_events = count_rolling_events(rolling_indicators)

    %{
      rolling_events: rolling_events,
      rolling_frequency: calculate_rolling_frequency(rolling_events),
      rolling_effectiveness: assess_rolling_effectiveness(rolling_indicators),
      active_rollers: identify_active_rollers(rolling_indicators)
    }
  end

  @doc """
  Analyze response time metrics for defensive actions.
  """
  @spec analyze_response_metrics(list()) :: map()
  def analyze_response_metrics(killmails) do
    response_events = identify_response_events(killmails)

    if Enum.empty?(response_events) do
      %{
        average_response_time: 0,
        response_events: 0,
        response_effectiveness: 0.0,
        response_patterns: %{}
      }
    else
      response_times = Enum.map(response_events, & &1.response_time)

      %{
        average_response_time: Enum.sum(response_times) / length(response_times),
        response_events: length(response_events),
        response_effectiveness: calculate_response_effectiveness(response_events),
        response_patterns: analyze_response_patterns(response_events)
      }
    end
  end

  @doc """
  Analyze defensive capabilities based on member fleet composition and activity.
  """
  @spec analyze_defensive_capabilities(list(), list()) :: map()
  def analyze_defensive_capabilities(members, killmails) do
    fleet_compositions = analyze_fleet_compositions(killmails)
    member_capabilities = assess_member_capabilities(members, killmails)

    %{
      fleet_strength: calculate_fleet_strength(fleet_compositions),
      member_readiness: calculate_member_readiness(member_capabilities),
      doctrine_adherence: assess_doctrine_adherence(fleet_compositions),
      defensive_assets: identify_defensive_assets(killmails)
    }
  end

  # Private helper functions

  defp get_corporation_info(corporation_id) do
    # Simplified corp info retrieval
    try do
      # In a real implementation, this would fetch from ESI or cache
      {:ok,
       %{
         id: corporation_id,
         name: "Corporation #{corporation_id}",
         # Placeholder
         member_count: 50
       }}
    rescue
      error ->
        Logger.error("Failed to get corporation info: #{inspect(error)}")
        {:error, "Failed to fetch corporation information"}
    end
  end

  defp get_corporation_members(corporation_id) do
    # Simplified member retrieval
    try do
      # In a real implementation, this would fetch from database
      {:ok,
       Enum.map(1..10, fn i ->
         %{character_id: corporation_id * 100 + i, name: "Member #{i}"}
       end)}
    rescue
      error ->
        Logger.error("Failed to get corporation members: #{inspect(error)}")
        {:error, "Failed to fetch corporation members"}
    end
  end

  defp get_corporation_killmails(corporation_id, start_date, end_date) do
    try do
      # Simplified killmail retrieval
      case QueryUtils.query_killmails_by_corporation(corporation_id, start_date, end_date,
             limit: 1000
           ) do
        killmails when is_list(killmails) -> {:ok, killmails}
        _ -> {:ok, []}
      end
    rescue
      error ->
        Logger.warning("Failed to get corporation killmails: #{inspect(error)}")
        {:ok, []}
    end
  end

  defp calculate_hourly_activity(killmails) do
    killmails
    |> Enum.group_by(fn km ->
      km.killmail_time
      |> DateTime.to_time()
      |> Time.to_erl()
      # Extract hour
      |> elem(0)
    end)
    |> Enum.map(fn {hour, kms} -> {hour, length(kms)} end)
    |> Enum.into(%{})
  end

  defp calculate_coverage_score(active_hours) do
    coverage_ratio = length(active_hours) / 24
    round(coverage_ratio * 100)
  end

  defp identify_active_timezones(active_hours) do
    # Simplified timezone identification
    cond do
      Enum.any?(active_hours, &(&1 >= 0 and &1 < 8)) -> [:asia]
      Enum.any?(active_hours, &(&1 >= 8 and &1 < 16)) -> [:europe]
      Enum.any?(active_hours, &(&1 >= 16 and &1 < 24)) -> [:us]
      true -> [:mixed]
    end
  end

  defp identify_peak_hours(hourly_activity) do
    hourly_activity
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(3)
    |> Enum.map(&elem(&1, 0))
  end

  defp identify_timezone_gaps(active_hours) do
    all_hours = MapSet.new(0..23)
    active_set = MapSet.new(active_hours)

    all_hours
    |> MapSet.difference(active_set)
    |> MapSet.to_list()
    # Group consecutive gaps
    |> Enum.chunk_every(2)
  end

  defp identify_rolling_indicators(killmails) do
    # Simplified rolling detection based on system patterns
    Enum.filter(killmails, fn km ->
      # Look for wormhole system kills that might indicate rolling
      km.solar_system_id >= 31_000_000 and km.solar_system_id < 32_000_000
    end)
    |> Enum.group_by(& &1.solar_system_id)
    # Potential rolling activity
    |> Enum.filter(fn {_system, kills} -> length(kills) > 3 end)
  end

  defp count_rolling_events(rolling_indicators) do
    map_size(rolling_indicators)
  end

  defp calculate_rolling_frequency(rolling_events) do
    # Simplified frequency calculation
    if rolling_events > 0 do
      # Basic scoring
      min(100, rolling_events * 10)
    else
      0
    end
  end

  defp assess_rolling_effectiveness(rolling_indicators) do
    if map_size(rolling_indicators) > 0 do
      :effective
    else
      :minimal
    end
  end

  defp identify_active_rollers(rolling_indicators) do
    Enum.flat_map(rolling_indicators, fn {_system, kills} ->
      Enum.flat_map(kills, fn km -> km.participants || [] end)
    end)
    |> Enum.group_by(& &1.character_id)
    |> Enum.filter(fn {_char_id, participations} -> length(participations) > 2 end)
    |> Enum.map(&elem(&1, 0))
  end

  defp identify_response_events(killmails) do
    # Simplified response event identification
    Enum.filter(killmails, fn km ->
      # Look for defensive kills (multiple corp members involved)
      corp_participants =
        Enum.count(km.participants || [], fn _p ->
          # This would check if participant is from the analyzed corp
          # Simplified
          true
        end)

      corp_participants > 3
    end)
    |> Enum.map(fn km ->
      %{
        killmail_id: km.id,
        # Placeholder response time in seconds
        response_time: :rand.uniform(300),
        participants: length(km.participants || [])
      }
    end)
  end

  defp calculate_response_effectiveness(response_events) do
    if length(response_events) > 0 do
      avg_participants =
        Enum.map(response_events, & &1.participants)
        |> Enum.sum()
        |> Kernel./(length(response_events))

      # Normalize to 0-1
      min(1.0, avg_participants / 10)
    else
      0.0
    end
  end

  defp analyze_response_patterns(response_events) do
    %{
      total_responses: length(response_events),
      avg_participants:
        if(length(response_events) > 0,
          do: Enum.sum(Enum.map(response_events, & &1.participants)) / length(response_events),
          else: 0
        )
    }
  end

  defp analyze_fleet_compositions(killmails) do
    # Simplified fleet composition analysis
    ship_types =
      Enum.flat_map(killmails, fn km -> km.participants || [] end)
      |> Enum.map(& &1.ship_type_id)
      |> Enum.frequencies()

    %{
      ship_diversity: map_size(ship_types),
      most_used_ships: ship_types |> Enum.sort_by(&elem(&1, 1), :desc) |> Enum.take(5)
    }
  end

  defp assess_member_capabilities(members, killmails) do
    # Simplified capability assessment
    active_members =
      Enum.flat_map(killmails, fn km -> km.participants || [] end)
      |> Enum.map(& &1.character_id)
      |> Enum.uniq()

    %{
      active_member_ratio: length(active_members) / length(members),
      total_active_members: length(active_members)
    }
  end

  defp calculate_fleet_strength(fleet_compositions) do
    diversity_score = min(100, Map.get(fleet_compositions, :ship_diversity, 0) * 10)
    round(diversity_score)
  end

  defp calculate_member_readiness(member_capabilities) do
    ratio = Map.get(member_capabilities, :active_member_ratio, 0)
    round(ratio * 100)
  end

  defp assess_doctrine_adherence(fleet_compositions) do
    # Simplified doctrine assessment
    ship_count = Map.get(fleet_compositions, :ship_diversity, 0)

    cond do
      ship_count > 20 -> :diverse
      ship_count > 10 -> :moderate
      ship_count > 5 -> :focused
      true -> :limited
    end
  end

  defp identify_defensive_assets(_killmails) do
    # Placeholder for defensive asset identification
    %{
      capital_ships: 0,
      strategic_cruisers: 0,
      logistics_ships: 0
    }
  end

  defp calculate_defense_score(timezone_coverage, rolling_participation, response_metrics) do
    coverage_score = Map.get(timezone_coverage, :coverage_score, 0)
    rolling_score = Map.get(rolling_participation, :rolling_frequency, 0)
    response_score = Map.get(response_metrics, :response_effectiveness, 0) * 100

    total_score = (coverage_score + rolling_score + response_score) / 3
    round(total_score)
  end

  defp identify_coverage_gaps(timezone_coverage, response_metrics) do
    tz_gaps = Map.get(timezone_coverage, :coverage_gaps, [])
    response_events = Map.get(response_metrics, :response_events, 0)

    gaps = []
    gaps = if length(tz_gaps) > 8, do: ["Significant timezone gaps" | gaps], else: gaps
    gaps = if response_events < 5, do: ["Low response activity" | gaps], else: gaps

    gaps
  end

  defp save_analysis_results(analysis) do
    # Save to HomeDefenseAnalytics resource
    analytics_params = %{
      corporation_id: analysis.corporation_id,
      defense_score: analysis.defense_score,
      timezone_coverage_score: Map.get(analysis.timezone_coverage, :coverage_score, 0),
      rolling_participation_score: Map.get(analysis.rolling_participation, :rolling_frequency, 0),
      response_effectiveness: Map.get(analysis.response_metrics, :response_effectiveness, 0),
      analysis_data: analysis,
      created_at: DateTime.utc_now()
    }

    case Ash.create(HomeDefenseAnalytics, analytics_params, domain: Api) do
      {:ok, _analytics} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to save home defense analysis: #{inspect(reason)}")
        # Don't fail the analysis if save fails
        :ok
    end
  rescue
    error ->
      Logger.warning("Error saving home defense analysis: #{inspect(error)}")
      :ok
  end
end
