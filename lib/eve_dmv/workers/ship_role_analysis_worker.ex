defmodule EveDmv.Workers.ShipRoleAnalysisWorker do
  @moduledoc """
  Background worker for continuous ship role pattern analysis.

  This worker periodically analyzes recent killmail data to update ship role
  classifications, track meta trends, and maintain accurate role confidence
  scores based on real fleet usage patterns.

  Note: Designed to be easily migrated to Oban when available.
  """

  use GenServer
  require Logger

  alias EveDmv.Analytics.ModuleClassifier
  alias EveDmv.Repo
  import Ecto.Query

  # Configuration
  # 6 hours
  @analysis_interval_ms 1000 * 60 * 60 * 6
  @recent_data_days 7
  @min_sample_size 5

  defmodule State do
    @moduledoc false
    defstruct [
      :timer_ref,
      :last_analysis,
      :stats
    ]
  end

  ## Public API

  @doc """
  Start the ship role analysis worker.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Trigger an immediate analysis run.
  """
  def analyze_now do
    # 5 minute timeout
    GenServer.call(__MODULE__, :analyze_now, 300_000)
  end

  @doc """
  Get current worker statistics.
  """
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Perform ship role analysis for recent killmails.

  This is the main analysis function that can be called directly
  or by the background worker.
  """
  def perform_analysis do
    Logger.info("Starting ship role analysis for recent killmails")

    start_time = System.monotonic_time(:millisecond)

    try do
      # Get recent killmail data grouped by ship type
      ship_killmail_data = fetch_recent_killmail_data()

      Logger.info("Analyzing #{map_size(ship_killmail_data)} ship types")

      # Analyze each ship type
      results =
        ship_killmail_data
        |> Enum.map(fn {ship_type_id, killmails} ->
          analyze_ship_type(ship_type_id, killmails)
        end)
        |> Enum.filter(&match?({:ok, _}, &1))
        |> Enum.map(fn {:ok, result} -> result end)

      # Update cached ship role classifications
      update_stats = update_ship_role_cache(results)

      # Generate meta trend report
      trend_stats = generate_meta_trend_report(results)

      # Record analysis history
      record_analysis_history(results)

      end_time = System.monotonic_time(:millisecond)
      duration_ms = end_time - start_time

      stats = %{
        duration_ms: duration_ms,
        ships_analyzed: length(results),
        killmails_processed:
          ship_killmail_data |> Enum.map(fn {_, killmails} -> length(killmails) end) |> Enum.sum(),
        cache_updates: update_stats,
        trends_detected: trend_stats,
        completed_at: DateTime.utc_now()
      }

      Logger.info("Ship role analysis completed in #{duration_ms}ms: #{inspect(stats)}")

      {:ok, stats}
    rescue
      error ->
        Logger.error("Ship role analysis failed: #{inspect(error)}")
        {:error, error}
    end
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    # Schedule the first analysis
    timer_ref = schedule_next_analysis()

    state = %State{
      timer_ref: timer_ref,
      last_analysis: nil,
      stats: %{}
    }

    Logger.info("Ship role analysis worker started")

    {:ok, state}
  end

  @impl true
  def handle_call(:analyze_now, _from, state) do
    # Cancel existing timer and run analysis now
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    case perform_analysis() do
      {:ok, stats} ->
        # Schedule next analysis
        timer_ref = schedule_next_analysis()

        new_state = %{
          state
          | timer_ref: timer_ref,
            last_analysis: DateTime.utc_now(),
            stats: stats
        }

        {:reply, {:ok, stats}, new_state}

      {:error, reason} ->
        # Still schedule next analysis even if this one failed
        timer_ref = schedule_next_analysis()
        new_state = %{state | timer_ref: timer_ref}

        {:reply, {:error, reason}, new_state}
    end
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl true
  def handle_info(:run_analysis, state) do
    case perform_analysis() do
      {:ok, stats} ->
        # Schedule next analysis
        timer_ref = schedule_next_analysis()

        new_state = %{
          state
          | timer_ref: timer_ref,
            last_analysis: DateTime.utc_now(),
            stats: stats
        }

        {:noreply, new_state}

      {:error, reason} ->
        Logger.error("Scheduled ship role analysis failed: #{inspect(reason)}")

        # Still schedule next analysis
        timer_ref = schedule_next_analysis()
        new_state = %{state | timer_ref: timer_ref}

        {:noreply, new_state}
    end
  end

  ## Private Functions

  defp schedule_next_analysis do
    Process.send_after(self(), :run_analysis, @analysis_interval_ms)
  end

  defp fetch_recent_killmail_data do
    cutoff_date = DateTime.utc_now() |> DateTime.add(-@recent_data_days, :day)

    # Query recent killmails with victim ship data
    query =
      from(k in "killmails_raw",
        where: k.killmail_time >= ^cutoff_date,
        select: %{
          killmail_id: k.killmail_id,
          killmail_time: k.killmail_time,
          victim_ship_type_id: k.victim_ship_type_id,
          raw_data: k.raw_data
        }
      )

    killmails = Repo.all(query)

    # Group by ship type
    Enum.group_by(killmails, & &1.victim_ship_type_id)
  end

  defp analyze_ship_type(ship_type_id, killmails) do
    Logger.debug("Analyzing ship type #{ship_type_id} with #{length(killmails)} killmails")

    # Skip analysis if insufficient data
    if length(killmails) < @min_sample_size do
      Logger.debug("Skipping ship type #{ship_type_id}: insufficient sample size")
      {:skip, :insufficient_data}
    else
      try do
        # Analyze each killmail and aggregate role classifications
        role_classifications =
          killmails
          |> Enum.map(&classify_killmail_role/1)
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, classification} -> classification end)

        if length(role_classifications) > 0 do
          # Aggregate role distributions
          aggregated_roles = aggregate_role_distributions(role_classifications)

          # Calculate confidence score based on consistency and sample size
          confidence_score = calculate_confidence_score(role_classifications, length(killmails))

          # Determine primary role
          primary_role = determine_primary_role(aggregated_roles)

          # Detect meta trends (compare with historical data)
          meta_trend = detect_meta_trend(ship_type_id, aggregated_roles)

          result = %{
            ship_type_id: ship_type_id,
            primary_role: primary_role,
            role_distribution: aggregated_roles,
            confidence_score: confidence_score,
            sample_size: length(killmails),
            meta_trend: meta_trend,
            analyzed_at: DateTime.utc_now()
          }

          {:ok, result}
        else
          Logger.debug("No valid role classifications for ship type #{ship_type_id}")
          {:skip, :no_valid_classifications}
        end
      rescue
        error ->
          Logger.error("Failed to analyze ship type #{ship_type_id}: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  defp classify_killmail_role(killmail) do
    try do
      # Use our ModuleClassifier to analyze the killmail
      case ModuleClassifier.classify_ship_role(killmail.raw_data) do
        classification when is_map(classification) ->
          {:ok, classification}

        _ ->
          {:error, :invalid_classification}
      end
    rescue
      error ->
        Logger.debug("Failed to classify killmail #{killmail.killmail_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  defp aggregate_role_distributions(classifications) do
    # Sum up all role scores and normalize
    total_classifications = length(classifications)

    aggregated =
      classifications
      |> Enum.reduce(%{}, fn classification, acc ->
        Enum.reduce(classification, acc, fn {role, score}, role_acc ->
          Map.update(role_acc, role, score, &(&1 + score))
        end)
      end)
      |> Enum.map(fn {role, total_score} ->
        {role, total_score / total_classifications}
      end)
      |> Enum.into(%{})

    # Ensure all roles are present with at least 0.0
    base_roles = %{tackle: 0.0, logistics: 0.0, ewar: 0.0, dps: 0.0, command: 0.0, support: 0.0}
    Map.merge(base_roles, aggregated)
  end

  defp calculate_confidence_score(classifications, sample_size) do
    # Calculate consistency score (lower variance = higher confidence)
    consistency_score = calculate_consistency(classifications)

    # Sample size bonus (more data = higher confidence, with diminishing returns)
    sample_factor = :math.log(sample_size + 1) / 10
    sample_score = min(1.0, sample_factor)

    # Combine scores with weights
    base_score = consistency_score * 0.7 + sample_score * 0.3

    # Apply minimum and maximum bounds
    min(1.0, max(0.1, base_score))
  end

  defp calculate_consistency(classifications) do
    if length(classifications) < 2 do
      # Default for single classification
      0.5
    else
      # Calculate variance in primary role assignments
      primary_roles = Enum.map(classifications, &determine_primary_role/1)
      role_counts = Enum.frequencies(primary_roles)
      most_common_count = Enum.max(Map.values(role_counts))

      # Consistency is the percentage of classifications that agree on primary role
      most_common_count / length(classifications)
    end
  end

  defp determine_primary_role(role_distribution) do
    {primary_role, _score} = Enum.max_by(role_distribution, fn {_role, score} -> score end)
    primary_role
  end

  defp detect_meta_trend(ship_type_id, current_roles) do
    # Get historical data for this ship
    historical_query =
      from(h in "role_analysis_history",
        where: h.ship_type_id == ^ship_type_id,
        where: h.analysis_date >= ago(30, "day"),
        order_by: [desc: h.analysis_date],
        limit: 5,
        select: %{
          analysis_date: h.analysis_date,
          role_distribution: h.role_distribution
        }
      )

    historical_data = Repo.all(historical_query)

    if length(historical_data) < 2 do
      # Not enough historical data
      "stable"
    else
      # Compare current primary role with historical trend
      current_primary = determine_primary_role(current_roles)

      historical_primaries =
        historical_data
        |> Enum.map(fn %{role_distribution: dist} ->
          determine_primary_role(dist)
        end)

      # Check for role shifts
      recent_primary = List.first(historical_primaries)

      cond do
        current_primary != recent_primary -> "shifting"
        Enum.all?(historical_primaries, &(&1 == current_primary)) -> "stable"
        true -> "evolving"
      end
    end
  end

  defp update_ship_role_cache(analysis_results) do
    Logger.info("Updating ship role cache with #{length(analysis_results)} results")

    {updated_count, failed_count} =
      analysis_results
      |> Enum.reduce({0, 0}, fn result, {updated, failed} ->
        case upsert_ship_role_pattern(result) do
          {:ok, _} -> {updated + 1, failed}
          {:error, _} -> {updated, failed + 1}
        end
      end)

    Logger.info("Cache update complete: #{updated_count} updated, #{failed_count} failed")

    %{updated: updated_count, failed: failed_count}
  end

  defp upsert_ship_role_pattern(analysis_result) do
    attrs = %{
      ship_type_id: analysis_result.ship_type_id,
      primary_role: to_string(analysis_result.primary_role),
      role_distribution: analysis_result.role_distribution,
      confidence_score: Decimal.from_float(analysis_result.confidence_score),
      sample_size: analysis_result.sample_size,
      last_analyzed: analysis_result.analyzed_at,
      meta_trend: analysis_result.meta_trend,
      updated_at: DateTime.utc_now()
    }

    # Check if record exists
    existing =
      Repo.one(
        from(s in "ship_role_patterns",
          where: s.ship_type_id == ^analysis_result.ship_type_id,
          select: %{ship_type_id: s.ship_type_id}
        )
      )

    case existing do
      nil ->
        # Insert new record (merge with any reference data)
        reference_attrs = get_reference_attrs(analysis_result.ship_type_id)
        full_attrs = Map.merge(reference_attrs, attrs)
        full_attrs = Map.put(full_attrs, :inserted_at, DateTime.utc_now())

        case Repo.insert_all("ship_role_patterns", [full_attrs]) do
          {1, _} -> {:ok, :inserted}
          _ -> {:error, :insert_failed}
        end

      _ ->
        # Update existing record
        case Repo.update_all(
               from(s in "ship_role_patterns",
                 where: s.ship_type_id == ^analysis_result.ship_type_id
               ),
               set: [
                 primary_role: attrs.primary_role,
                 role_distribution: attrs.role_distribution,
                 confidence_score: attrs.confidence_score,
                 sample_size: attrs.sample_size,
                 last_analyzed: attrs.last_analyzed,
                 meta_trend: attrs.meta_trend,
                 updated_at: attrs.updated_at
               ]
             ) do
          {1, _} -> {:ok, :updated}
          _ -> {:error, :update_failed}
        end
    end
  end

  defp get_reference_attrs(ship_type_id) do
    # Get ship name from eve_item_types if available
    ship_info =
      Repo.one(
        from(i in "eve_item_types",
          where: i.type_id == ^ship_type_id,
          select: %{type_name: i.type_name}
        )
      )

    %{
      ship_name: ship_info[:type_name] || "Unknown Ship",
      reference_role: nil,
      typical_doctrines: [],
      tactical_notes: nil
    }
  end

  defp generate_meta_trend_report(analysis_results) do
    trends =
      analysis_results
      |> Enum.group_by(& &1.meta_trend)
      |> Enum.map(fn {trend, results} -> {trend, length(results)} end)
      |> Enum.into(%{})

    Logger.info("Meta trends detected: #{inspect(trends)}")
    trends
  end

  defp record_analysis_history(analysis_results) do
    today = Date.utc_today()

    history_records =
      analysis_results
      |> Enum.map(fn result ->
        %{
          ship_type_id: result.ship_type_id,
          analysis_date: today,
          role_distribution: result.role_distribution,
          meta_indicators: %{
            confidence_score: result.confidence_score,
            sample_size: result.sample_size,
            meta_trend: result.meta_trend
          },
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)

    # Insert history records (ignore duplicates for same ship + date)
    case Repo.insert_all("role_analysis_history", history_records,
           on_conflict: :nothing,
           conflict_target: [:ship_type_id, :analysis_date]
         ) do
      {count, _} ->
        Logger.info("Recorded #{count} history entries")
        {:ok, count}
    end
  end
end
