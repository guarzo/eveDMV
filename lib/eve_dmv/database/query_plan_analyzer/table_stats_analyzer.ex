defmodule EveDmv.Database.QueryPlanAnalyzer.TableStatsAnalyzer do
  @moduledoc """
  Table statistics analysis module for database health monitoring.

  Analyzes table usage patterns, bloat ratios, index effectiveness,
  and provides maintenance recommendations for optimal database performance.
  """

  alias Ecto.Adapters.SQL
  alias EveDmv.Repo
  require Logger

  @doc """
  Analyzes statistics for a specific table.

  Retrieves comprehensive statistics including row counts, scan patterns,
  index usage, and bloat information for performance analysis.
  """
  def analyze_table_statistics(table_name) do
    # Get table size and row count
    size_query = """
    SELECT
      schemaname,
      tablename,
      attname,
      n_distinct,
      correlation,
      most_common_vals,
      most_common_freqs
    FROM pg_stats
    WHERE tablename = $1
    AND schemaname = 'public'
    """

    stats_query = """
    SELECT
      schemaname,
      tablename,
      seq_scan,
      seq_tup_read,
      idx_scan,
      idx_tup_fetch,
      n_tup_ins,
      n_tup_upd,
      n_tup_del,
      n_live_tup,
      n_dead_tup,
      last_vacuum,
      last_autovacuum,
      last_analyze,
      last_autoanalyze
    FROM pg_stat_user_tables
    WHERE tablename = $1
    AND schemaname = 'public'
    """

    with {:ok, %{rows: stats_rows}} <- SQL.query(Repo, stats_query, [table_name]),
         {:ok, %{rows: size_rows}} <- SQL.query(Repo, size_query, [table_name]) do
      case stats_rows do
        [
          [
            _schema,
            table,
            seq_scan,
            seq_tup_read,
            idx_scan,
            idx_tup_fetch,
            n_tup_ins,
            n_tup_upd,
            n_tup_del,
            n_live_tup,
            n_dead_tup,
            last_vacuum,
            last_autovacuum,
            last_analyze,
            last_autoanalyze
          ]
        ] ->
          %{
            table_name: table,
            sequential_scans: seq_scan,
            sequential_tuples_read: seq_tup_read,
            index_scans: idx_scan,
            index_tuples_fetched: idx_tup_fetch,
            tuples_inserted: n_tup_ins,
            tuples_updated: n_tup_upd,
            tuples_deleted: n_tup_del,
            live_tuples: n_live_tup,
            dead_tuples: n_dead_tup,
            bloat_ratio:
              if(n_live_tup > 0, do: n_dead_tup / (n_live_tup + n_dead_tup), else: 0.0),
            column_stats: parse_column_stats(size_rows),
            maintenance_info: %{
              last_vacuum: last_vacuum,
              last_autovacuum: last_autovacuum,
              last_analyze: last_analyze,
              last_autoanalyze: last_autoanalyze
            },
            usage_patterns:
              analyze_usage_patterns(seq_scan, idx_scan, seq_tup_read, idx_tup_fetch),
            recommendations:
              generate_table_recommendations(
                seq_scan,
                idx_scan,
                n_dead_tup,
                n_live_tup,
                last_analyze
              )
          }

        _ ->
          nil
      end
    else
      {:error, error} ->
        Logger.warning("Failed to analyze table #{table_name}: #{inspect(error)}")
        nil
    end
  end

  @doc """
  Analyzes critical tables for the EVE DMV application.
  """
  def analyze_critical_tables do
    critical_tables = [
      "killmails_raw",
      "participants",
      "character_stats",
      "surveillance_profiles",
      "user_tokens"
    ]

    critical_tables
    |> Enum.map(&analyze_table_statistics/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Generates comprehensive table health report.
  """
  def generate_table_health_report(table_stats) do
    %{
      total_tables_analyzed: length(table_stats),
      health_summary: calculate_overall_health(table_stats),
      bloat_analysis: analyze_bloat_patterns(table_stats),
      usage_efficiency: analyze_usage_efficiency(table_stats),
      maintenance_status: analyze_maintenance_status(table_stats),
      top_recommendations: compile_top_recommendations(table_stats)
    }
  end

  @doc """
  Identifies tables that need immediate maintenance attention.
  """
  def identify_maintenance_candidates(table_stats) do
    candidates =
      Enum.filter(table_stats, fn table ->
        needs_vacuum = table.bloat_ratio > 0.2
        needs_analyze = stale_statistics?(table.maintenance_info)
        high_sequential_scans = table.usage_patterns.sequential_scan_ratio > 0.3

        needs_vacuum or needs_analyze or high_sequential_scans
      end)

    candidates
    |> Enum.map(fn table ->
      %{
        table_name: table.table_name,
        priority: calculate_maintenance_priority(table),
        issues: identify_table_issues(table),
        recommended_actions: get_maintenance_actions(table)
      }
    end)
    |> Enum.sort_by(& &1.priority, :desc)
  end

  @doc """
  Analyzes index effectiveness across tables.
  """
  def analyze_index_effectiveness(table_stats) do
    Enum.map(table_stats, fn table ->
      %{
        table_name: table.table_name,
        index_usage_ratio: calculate_index_usage_ratio(table),
        scan_efficiency: calculate_scan_efficiency(table),
        index_recommendations: generate_index_recommendations_for_table(table)
      }
    end)
  end

  @doc """
  Monitors table growth patterns and predicts future storage needs.
  """
  def analyze_growth_patterns(table_stats) do
    Enum.map(table_stats, fn table ->
      daily_growth = estimate_daily_growth(table)

      %{
        table_name: table.table_name,
        current_size: table.live_tuples + table.dead_tuples,
        estimated_daily_growth: daily_growth,
        growth_trend: classify_growth_trend(daily_growth),
        projected_size_30_days: table.live_tuples + table.dead_tuples + daily_growth * 30,
        storage_recommendations: generate_storage_recommendations(table, daily_growth)
      }
    end)
  end

  @doc """
  Generates SQL commands for table maintenance.
  """
  def generate_maintenance_commands(table_name, issues) do
    base_commands = []

    vacuum_commands =
      if "high_bloat" in issues do
        ["VACUUM FULL #{table_name};" | base_commands]
      else
        base_commands
      end

    analyze_commands =
      if "stale_statistics" in issues do
        ["ANALYZE #{table_name};" | vacuum_commands]
      else
        vacuum_commands
      end

    index_commands =
      if "missing_indexes" in issues do
        ["-- Review and add appropriate indexes for #{table_name}" | analyze_commands]
      else
        analyze_commands
      end

    final_commands =
      if "high_sequential_scans" in issues do
        [
          "-- Consider adding indexes to reduce sequential scans on #{table_name}"
          | index_commands
        ]
      else
        index_commands
      end

    final_commands
  end

  # Private helper functions

  defp parse_column_stats(rows) do
    Enum.map(rows, fn [_schema, _table, column, n_distinct, correlation, _vals, _freqs] ->
      %{
        column_name: column,
        distinct_values: n_distinct,
        correlation: correlation,
        selectivity: calculate_column_selectivity(n_distinct)
      }
    end)
  end

  defp calculate_column_selectivity(n_distinct) when is_number(n_distinct) and n_distinct > 0 do
    # Higher distinct values = better selectivity for indexing
    cond do
      n_distinct > 1000 -> "High"
      n_distinct > 100 -> "Medium"
      n_distinct > 10 -> "Low"
      true -> "Very Low"
    end
  end

  defp calculate_column_selectivity(_), do: "Unknown"

  defp analyze_usage_patterns(seq_scan, idx_scan, seq_tup_read, idx_tup_fetch) do
    total_scans = (seq_scan || 0) + (idx_scan || 0)
    _total_tuples = (seq_tup_read || 0) + (idx_tup_fetch || 0)

    %{
      total_scans: total_scans,
      sequential_scan_ratio: if(total_scans > 0, do: (seq_scan || 0) / total_scans, else: 0.0),
      index_scan_ratio: if(total_scans > 0, do: (idx_scan || 0) / total_scans, else: 0.0),
      avg_tuples_per_seq_scan:
        if(seq_scan && seq_scan > 0, do: (seq_tup_read || 0) / seq_scan, else: 0),
      avg_tuples_per_idx_scan:
        if(idx_scan && idx_scan > 0, do: (idx_tup_fetch || 0) / idx_scan, else: 0),
      scan_efficiency: classify_scan_efficiency(seq_scan, idx_scan, seq_tup_read, idx_tup_fetch)
    }
  end

  defp classify_scan_efficiency(seq_scan, idx_scan, _seq_tup_read, _idx_tup_fetch) do
    seq_ratio =
      if (seq_scan || 0) + (idx_scan || 0) > 0,
        do: (seq_scan || 0) / ((seq_scan || 0) + (idx_scan || 0)),
        else: 0

    cond do
      seq_ratio < 0.1 -> "Excellent"
      seq_ratio < 0.3 -> "Good"
      seq_ratio < 0.6 -> "Fair"
      true -> "Poor"
    end
  end

  defp generate_table_recommendations(seq_scan, idx_scan, dead_tuples, live_tuples, last_analyze) do
    base_recommendations = []

    # High sequential scan ratio
    scan_performance_recommendations =
      if seq_scan > 0 and idx_scan > 0 and seq_scan / (seq_scan + idx_scan) > 0.1 do
        ["Table has high sequential scan ratio - consider adding indexes" | base_recommendations]
      else
        base_recommendations
      end

    # High bloat ratio
    bloat_management_recommendations =
      if live_tuples > 0 and dead_tuples / (live_tuples + dead_tuples) > 0.1 do
        [
          "Table has high bloat ratio (#{Float.round(dead_tuples / (live_tuples + dead_tuples) * 100, 1)}%) - consider VACUUM"
          | scan_performance_recommendations
        ]
      else
        scan_performance_recommendations
      end

    # Stale statistics
    final_recommendations =
      if stale_statistics?(%{last_analyze: last_analyze}) do
        [
          "Table statistics are stale - run ANALYZE for better query planning"
          | bloat_management_recommendations
        ]
      else
        bloat_management_recommendations
      end

    final_recommendations
  end

  defp stale_statistics?(maintenance_info) do
    last_analyze = maintenance_info.last_analyze || maintenance_info.last_autoanalyze

    case last_analyze do
      nil ->
        true

      date when is_binary(date) ->
        case DateTime.from_iso8601(date) do
          {:ok, datetime, _} -> DateTime.diff(DateTime.utc_now(), datetime, :day) > 7
          _ -> true
        end

      %DateTime{} = datetime ->
        DateTime.diff(DateTime.utc_now(), datetime, :day) > 7

      _ ->
        true
    end
  end

  defp calculate_overall_health(table_stats) do
    if table_stats == [] do
      %{score: 0, status: "No Data"}
    else
      total_score =
        table_stats
        |> Enum.map(&calculate_table_health_score/1)
        |> Enum.sum()

      avg_score = total_score / length(table_stats)

      status =
        cond do
          avg_score >= 80 -> "Healthy"
          avg_score >= 60 -> "Good"
          avg_score >= 40 -> "Fair"
          true -> "Poor"
        end

      %{score: avg_score, status: status}
    end
  end

  defp calculate_table_health_score(table) do
    # Penalty for bloat
    bloat_score = max(0, 100 - table.bloat_ratio * 500)
    # Reward for index usage
    scan_score = table.usage_patterns.index_scan_ratio * 100
    maintenance_score = if stale_statistics?(table.maintenance_info), do: 0, else: 100

    (bloat_score + scan_score + maintenance_score) / 3
  end

  defp analyze_bloat_patterns(table_stats) do
    bloated_tables = Enum.filter(table_stats, &(&1.bloat_ratio > 0.1))

    %{
      total_bloated_tables: length(bloated_tables),
      avg_bloat_ratio:
        if(length(table_stats) > 0,
          do: Enum.sum(Enum.map(table_stats, & &1.bloat_ratio)) / length(table_stats),
          else: 0
        ),
      highest_bloat:
        if(length(table_stats) > 0, do: Enum.max_by(table_stats, & &1.bloat_ratio), else: nil)
    }
  end

  defp analyze_usage_efficiency(table_stats) do
    %{
      avg_index_usage:
        if(length(table_stats) > 0,
          do:
            Enum.sum(Enum.map(table_stats, & &1.usage_patterns.index_scan_ratio)) /
              length(table_stats),
          else: 0
        ),
      tables_with_poor_efficiency:
        Enum.count(table_stats, &(&1.usage_patterns.sequential_scan_ratio > 0.5))
    }
  end

  defp analyze_maintenance_status(table_stats) do
    needs_vacuum = Enum.count(table_stats, &(&1.bloat_ratio > 0.1))
    needs_analyze = Enum.count(table_stats, &stale_statistics?(&1.maintenance_info))

    %{
      tables_needing_vacuum: needs_vacuum,
      tables_needing_analyze: needs_analyze,
      maintenance_urgency:
        classify_maintenance_urgency(needs_vacuum, needs_analyze, length(table_stats))
    }
  end

  defp classify_maintenance_urgency(vacuum_count, analyze_count, total_tables) do
    urgent_ratio = (vacuum_count + analyze_count) / max(total_tables, 1)

    cond do
      urgent_ratio > 0.5 -> "High"
      urgent_ratio > 0.3 -> "Medium"
      urgent_ratio > 0.1 -> "Low"
      true -> "None"
    end
  end

  defp compile_top_recommendations(table_stats) do
    table_stats
    |> Enum.flat_map(& &1.recommendations)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(5)
    |> Enum.map(fn {recommendation, count} ->
      "#{recommendation} (affects #{count} tables)"
    end)
  end

  defp calculate_maintenance_priority(table) do
    base_priority = 0

    bloat_priority = base_priority + if table.bloat_ratio > 0.3, do: 30, else: 0

    statistics_priority =
      bloat_priority + if stale_statistics?(table.maintenance_info), do: 20, else: 0

    scan_priority =
      statistics_priority + if table.usage_patterns.sequential_scan_ratio > 0.5, do: 25, else: 0

    # Large table bonus
    final_priority = scan_priority + if table.live_tuples > 1_000_000, do: 15, else: 0

    final_priority
  end

  defp identify_table_issues(table) do
    base_issues = []

    bloat_issues = if table.bloat_ratio > 0.2, do: ["high_bloat" | base_issues], else: base_issues

    statistics_issues =
      if stale_statistics?(table.maintenance_info),
        do: ["stale_statistics" | bloat_issues],
        else: bloat_issues

    scan_issues =
      if table.usage_patterns.sequential_scan_ratio > 0.3,
        do: ["high_sequential_scans" | statistics_issues],
        else: statistics_issues

    final_issues =
      if table.column_stats == [], do: ["missing_column_stats" | scan_issues], else: scan_issues

    final_issues
  end

  defp get_maintenance_actions(table) do
    base_actions = []

    vacuum_actions =
      if table.bloat_ratio > 0.2,
        do: ["VACUUM #{table.table_name}" | base_actions],
        else: base_actions

    analyze_actions =
      if stale_statistics?(table.maintenance_info),
        do: ["ANALYZE #{table.table_name}" | vacuum_actions],
        else: vacuum_actions

    final_actions =
      if table.usage_patterns.sequential_scan_ratio > 0.3,
        do: ["Review indexing strategy" | analyze_actions],
        else: analyze_actions

    final_actions
  end

  defp calculate_index_usage_ratio(table) do
    table.usage_patterns.index_scan_ratio
  end

  defp calculate_scan_efficiency(table) do
    case table.usage_patterns.scan_efficiency do
      "Excellent" -> 95
      "Good" -> 80
      "Fair" -> 60
      "Poor" -> 30
      _ -> 0
    end
  end

  defp generate_index_recommendations_for_table(table) do
    base_recommendations = []

    scan_recommendations =
      if table.usage_patterns.sequential_scan_ratio > 0.3 do
        ["Add indexes for frequently queried columns" | base_recommendations]
      else
        base_recommendations
      end

    final_recommendations =
      if table.usage_patterns.avg_tuples_per_seq_scan > 10_000 do
        ["Large sequential scans detected - add selective indexes" | scan_recommendations]
      else
        scan_recommendations
      end

    final_recommendations
  end

  defp estimate_daily_growth(table) do
    # Simple estimation based on insert rate
    # In practice, this would use historical data
    # Rough weekly average
    inserts_per_day = (table.tuples_inserted || 0) / 7
    inserts_per_day
  end

  defp classify_growth_trend(daily_growth) do
    cond do
      daily_growth > 10_000 -> "High Growth"
      daily_growth > 1000 -> "Medium Growth"
      daily_growth > 100 -> "Low Growth"
      daily_growth > 0 -> "Minimal Growth"
      true -> "Stable"
    end
  end

  defp generate_storage_recommendations(table, daily_growth) do
    base_recommendations = []

    growth_recommendations =
      if daily_growth > 10_000 do
        ["Consider partitioning strategy for high-growth table" | base_recommendations]
      else
        base_recommendations
      end

    final_recommendations =
      if table.bloat_ratio > 0.1 and daily_growth > 1000 do
        ["Schedule regular VACUUM to manage bloat in growing table" | growth_recommendations]
      else
        growth_recommendations
      end

    final_recommendations
  end
end
