# credo:disable-for-this-file Credo.Check.Refactor.ModuleDependencies
defmodule EveDmv.Database.QueryPlanAnalyzer do
  use GenServer

    alias EveDmv.Database.QueryPlanAnalyzer.PlanAnalyzer
  alias Ecto.Adapters.SQL
  alias EveDmv.Database.QueryPlanAnalyzer.BufferAnalyzer
  alias EveDmv.Database.QueryPlanAnalyzer.IndexAnalyzer
  alias EveDmv.Database.QueryPlanAnalyzer.SlowQueryDetector
  alias EveDmv.Database.QueryPlanAnalyzer.TableStatsAnalyzer
  alias EveDmv.Repo

  require Logger
  @moduledoc """
  Analyzes PostgreSQL query execution plans to identify performance bottlenecks
  and optimization opportunities.

  Provides automated query plan analysis, slow query detection, and
  optimization recommendations for the EVE DMV application.
  """



  # Extracted modules

  @analysis_interval :timer.hours(1)
  @slow_query_threshold_ms 1000
  @expensive_query_threshold_ms 5000

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def analyze_query(query, params \\ []) do
    GenServer.call(__MODULE__, {:analyze_query, query, params})
  end

  def get_slow_queries(limit \\ 10) do
    GenServer.call(__MODULE__, {:get_slow_queries, limit})
  end

  def get_analysis_report do
    GenServer.call(__MODULE__, :get_analysis_report)
  end

  def analyze_table_stats(table_name) do
    GenServer.call(__MODULE__, {:analyze_table_stats, table_name})
  end

  def suggest_indexes do
    GenServer.call(__MODULE__, :suggest_indexes)
  end

  def force_analysis do
    GenServer.cast(__MODULE__, :force_analysis)
  end

  # Server callbacks

  def init(opts) do
    state = %{
      enabled: Keyword.get(opts, :enabled, true),
      slow_queries: [],
      analysis_stats: %{
        total_queries_analyzed: 0,
        slow_queries_detected: 0,
        last_analysis: nil,
        recommendations: []
      }
    }

    if state.enabled do
      # Enable pg_stat_statements if available
      ensure_pg_stat_statements_enabled()
      schedule_analysis()
    end

    {:ok, state}
  end

  def handle_call({:analyze_query, query, params}, _from, state) do
    result = perform_query_analysis(query, params)
    {:reply, result, state}
  end

  def handle_call({:get_slow_queries, limit}, _from, state) do
    slow_queries = Enum.take(state.slow_queries, limit)
    {:reply, slow_queries, state}
  end

  def handle_call(:get_analysis_report, _from, state) do
    report = generate_analysis_report(state)
    {:reply, report, state}
  end

  def handle_call({:analyze_table_stats, table_name}, _from, state) do
    result = analyze_table_statistics(table_name)
    {:reply, result, state}
  end

  def handle_call(:suggest_indexes, _from, state) do
    suggestions = generate_index_suggestions()
    {:reply, suggestions, state}
  end

  def handle_cast(:force_analysis, state) do
    new_state = perform_periodic_analysis(state)
    {:noreply, new_state}
  end

  def handle_info(:perform_analysis, state) do
    new_state = perform_periodic_analysis(state)
    schedule_analysis()
    {:noreply, new_state}
  end

  def handle_info(_, state), do: {:noreply, state}

  # Private functions

  defp schedule_analysis do
    Process.send_after(self(), :perform_analysis, @analysis_interval)
  end

  defp ensure_pg_stat_statements_enabled do
    query = "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'pg_stat_statements')"

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: [[true]]}} ->
        Logger.info("pg_stat_statements extension is available")
        :ok

      {:ok, %{rows: [[_]]}} ->
        Logger.warning(
          "pg_stat_statements extension not available - limited analysis capabilities"
        )

        :not_available

      {:error, error} ->
        Logger.error("Failed to check pg_stat_statements: #{inspect(error)}")
        :error
    end
  end

  defp perform_query_analysis(query, params) do
    Logger.debug("Analyzing query: #{String.slice(query, 0, 100)}...")

    start_time = System.monotonic_time(:millisecond)

    # Get query execution plan
    explain_query = "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " <> query

    case SQL.query(Repo, explain_query, params) do
      {:ok, %{rows: [[json_plan]]}} ->
        execution_time = System.monotonic_time(:millisecond) - start_time

        analysis = analyze_execution_plan(json_plan, execution_time)
        recommendations = generate_query_recommendations(analysis)

        %{
          execution_time_ms: execution_time,
          plan: analysis,
          recommendations: recommendations,
          is_slow: execution_time > @slow_query_threshold_ms,
          is_expensive: execution_time > @expensive_query_threshold_ms
        }

      {:error, error} ->
        Logger.error("Failed to analyze query: #{inspect(error)}")
        %{error: "Query analysis failed", details: inspect(error)}
    end
  rescue
    error ->
      Logger.error("Exception during query analysis: #{inspect(error)}")
      %{error: "Analysis exception", details: inspect(error)}
  end

  defp analyze_execution_plan(json_plan, execution_time) do
    analysis = PlanAnalyzer.analyze_execution_plan(json_plan, execution_time)
    plan = Jason.decode!(json_plan)
    root_node = List.first(plan)["Plan"]

    Map.merge(analysis, %{
      buffer_usage: BufferAnalyzer.extract_buffer_usage(root_node),
      index_usage: IndexAnalyzer.extract_index_usage(root_node)
    })
  end

  # Delegation to extracted modules
  defdelegate extract_node_types(node, types \\ []), to: PlanAnalyzer
  defdelegate find_expensive_operations(node, expensive \\ []), to: PlanAnalyzer
  defdelegate calculate_row_estimation_errors(node, errors \\ []), to: PlanAnalyzer
  defdelegate extract_buffer_usage(node, usage \\ %{}), to: BufferAnalyzer
  defdelegate merge_buffer_usage(usage1, usage2), to: BufferAnalyzer
  defdelegate calculate_combined_cache_ratio(usage1, usage2), to: BufferAnalyzer
  defdelegate extract_index_usage(node, indexes \\ []), to: IndexAnalyzer

  defp generate_query_recommendations(analysis) do
    buffer_recommendations = BufferAnalyzer.generate_buffer_recommendations(analysis.buffer_usage)
    plan_recommendations = PlanAnalyzer.generate_plan_recommendations(analysis)

    index_recommendations =
      IndexAnalyzer.generate_index_recommendations(
        IndexAnalyzer.analyze_index_patterns(analysis.index_usage)
      )

    buffer_recommendations ++ plan_recommendations ++ index_recommendations
  end

  defp perform_periodic_analysis(state) do
    Logger.info("Starting periodic query plan analysis")

    start_time = System.monotonic_time(:millisecond)

    # Analyze slow queries from pg_stat_statements
    slow_queries = detect_slow_queries()

    # Analyze table statistics
    table_stats = analyze_critical_tables()

    # Generate index recommendations
    index_suggestions = generate_index_suggestions()

    duration_ms = System.monotonic_time(:millisecond) - start_time

    new_stats = %{
      total_queries_analyzed: state.analysis_stats.total_queries_analyzed + length(slow_queries),
      slow_queries_detected: length(slow_queries),
      last_analysis: DateTime.utc_now(),
      recommendations: index_suggestions,
      table_stats: table_stats,
      analysis_duration_ms: duration_ms
    }

    Logger.info(
      "Query plan analysis completed in #{duration_ms}ms - found #{length(slow_queries)} slow queries"
    )

    %{state | slow_queries: slow_queries, analysis_stats: new_stats}
  end

  defdelegate detect_slow_queries(), to: SlowQueryDetector

  defdelegate analyze_critical_tables(), to: TableStatsAnalyzer

  defdelegate analyze_table_statistics(table_name), to: TableStatsAnalyzer

  defp generate_index_suggestions do
    # Analyze query patterns to suggest indexes
    suggestions = []

    # Check for queries with WHERE clauses that might benefit from indexes
    where_clause_analysis = analyze_where_clause_patterns()

    # Check for queries with ORDER BY that might benefit from indexes
    order_by_analysis = analyze_order_by_patterns()

    # Check for JOIN conditions that might benefit from indexes
    join_analysis = analyze_join_patterns()

    suggestions ++ where_clause_analysis ++ order_by_analysis ++ join_analysis
  end

  defp analyze_where_clause_patterns do
    # This would analyze actual query logs to identify common WHERE patterns
    # For now, return some common patterns for EVE DMV
    [
      %{
        table: "participants",
        columns: ["character_id", "killmail_time"],
        reason: "Frequent character lookups with time range filters",
        estimated_benefit: "High"
      },
      %{
        table: "killmails_enriched",
        columns: ["solar_system_id", "killmail_time"],
        reason: "System-based queries with time filters",
        estimated_benefit: "High"
      },
      %{
        table: "character_stats",
        columns: ["last_calculated_at"],
        reason: "Finding stale character stats for updates",
        estimated_benefit: "Medium"
      }
    ]
  end

  defp analyze_order_by_patterns do
    [
      %{
        table: "killmails_enriched",
        columns: ["total_value", "killmail_time"],
        reason: "High-value killmail queries with time ordering",
        estimated_benefit: "Medium"
      }
    ]
  end

  defp analyze_join_patterns do
    [
      %{
        table: "participants",
        columns: ["alliance_id", "killmail_time"],
        reason: "Alliance activity analysis joins",
        estimated_benefit: "Medium"
      }
    ]
  end

  defp generate_analysis_report(state) do
    %{
      analysis_stats: state.analysis_stats,
      slow_query_count: length(state.slow_queries),
      recent_slow_queries: Enum.take(state.slow_queries, 5),
      system_health: assess_system_health(state),
      top_recommendations: get_top_recommendations(state)
    }
  end

  defp assess_system_health(state) do
    slow_query_count = length(state.slow_queries)

    health_score =
      cond do
        slow_query_count == 0 -> 100
        slow_query_count <= 5 -> 80
        slow_query_count <= 15 -> 60
        slow_query_count <= 30 -> 40
        true -> 20
      end

    status =
      cond do
        health_score >= 80 -> "Excellent"
        health_score >= 60 -> "Good"
        health_score >= 40 -> "Fair"
        true -> "Poor"
      end

    %{
      score: health_score,
      status: status,
      slow_queries_detected: slow_query_count,
      last_analysis: state.analysis_stats.last_analysis
    }
  end

  defp get_top_recommendations(state) do
    state.analysis_stats.recommendations
    |> Enum.filter(&(&1.estimated_benefit in ["High", "Medium"]))
    |> Enum.sort_by(&(&1.estimated_benefit == "High"), &>=/2)
    |> Enum.take(5)
  end

  # Public utilities

  def enable_query_logging do
    queries = [
      "SET log_statement = 'all'",
      "SET log_min_duration_statement = #{@slow_query_threshold_ms}",
      "SET log_checkpoints = on",
      "SET log_lock_waits = on"
    ]

    Enum.each(queries, fn query ->
      case SQL.query(Repo, query, []) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          Logger.warning("Failed to set logging parameter: #{inspect(error)}")
      end
    end)
  end

  defdelegate get_query_performance_metrics(), to: SlowQueryDetector
end
