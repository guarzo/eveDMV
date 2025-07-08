defmodule EveDmv.Telemetry.PerformanceMonitor.IndexPartitionAnalyzer do
  alias Ecto.Adapters.SQL

  require Logger
  @moduledoc """
  Analyzes index usage and partition health.

  Monitors index effectiveness, identifies unused indexes, and tracks
  partition health for optimal database performance.
  """


  @doc """
  Monitor index usage to identify unused indexes.
  """
  def get_index_usage_stats do
    query = """
    SELECT
      schemaname,
      tablename,
      indexname,
      idx_scan,
      idx_tup_read,
      idx_tup_fetch,
      pg_size_pretty(pg_relation_size(indexrelid)) as index_size
    FROM pg_stat_user_indexes
    WHERE schemaname = 'public'
    ORDER BY idx_scan
    LIMIT 20
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [schema, table, index, scans, reads, fetches, size] ->
          %{
            schema: schema,
            table: table,
            index: index,
            scans: scans || 0,
            tuples_read: reads || 0,
            tuples_fetched: fetches || 0,
            size: size,
            unused: (scans || 0) == 0
          }
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Check health of partitioned tables.
  """
  def check_partition_health do
    query = """
    WITH partition_info AS (
      SELECT
        parent.relname as parent_table,
        child.relname as partition_name,
        pg_size_pretty(pg_relation_size(child.oid)) as partition_size,
        pg_stat_get_live_tuples(child.oid) as row_count,
        pg_stat_get_last_vacuum_time(child.oid) as last_vacuum,
        pg_stat_get_last_autovacuum_time(child.oid) as last_autovacuum
      FROM pg_inherits
      JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
      JOIN pg_class child ON pg_inherits.inhrelid = child.oid
      WHERE parent.relnamespace = 'public'::regnamespace
    )
    SELECT * FROM partition_info
    ORDER BY parent_table, partition_name
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [parent, partition, size, count, vacuum, autovacuum] ->
          %{
            parent_table: parent,
            partition_name: partition,
            size: size,
            row_count: count || 0,
            last_vacuum: vacuum,
            last_autovacuum: autovacuum,
            needs_vacuum: needs_vacuum?(count, vacuum, autovacuum)
          }
        end)
        |> Enum.group_by(& &1.parent_table)

      {:error, _} ->
        %{}
    end
  end

  @doc """
  Analyze index effectiveness and provide recommendations.
  """
  def analyze_index_effectiveness do
    with {:ok, index_stats} <- get_detailed_index_stats(),
         {:ok, table_stats} <- get_table_scan_stats() do
      analysis = %{
        unused_indexes: find_unused_indexes(index_stats),
        inefficient_indexes: find_inefficient_indexes(index_stats),
        missing_indexes: suggest_missing_indexes(table_stats),
        duplicate_indexes: find_duplicate_indexes(),
        index_bloat: analyze_index_bloat()
      }

      {:ok, generate_index_report(analysis)}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get detailed statistics for all indexes.
  """
  def get_detailed_index_stats do
    query = """
    SELECT
      s.schemaname,
      s.tablename,
      s.indexrelname,
      s.idx_scan,
      s.idx_tup_read,
      s.idx_tup_fetch,
      pg_relation_size(s.indexrelid) as index_size_bytes,
      pg_size_pretty(pg_relation_size(s.indexrelid)) as index_size,
      i.indisunique,
      i.indisprimary,
      pg_get_indexdef(s.indexrelid) as index_definition
    FROM pg_stat_user_indexes s
    JOIN pg_index i ON s.indexrelid = i.indexrelid
    WHERE s.schemaname = 'public'
    ORDER BY s.tablename, s.indexrelname
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        stats =
          Enum.map(rows, fn [
                              schema,
                              table,
                              index,
                              scans,
                              reads,
                              fetches,
                              size_bytes,
                              size,
                              is_unique,
                              is_primary,
                              definition
                            ] ->
            %{
              schema: schema,
              table: table,
              index: index,
              scans: scans || 0,
              tuples_read: reads || 0,
              tuples_fetched: fetches || 0,
              size_bytes: size_bytes,
              size: size,
              is_unique: is_unique,
              is_primary: is_primary,
              definition: definition,
              efficiency: calculate_index_efficiency(scans, reads, fetches)
            }
          end)

        {:ok, stats}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Get table scan statistics to identify missing indexes.
  """
  def get_table_scan_stats do
    query = """
    SELECT
      schemaname,
      tablename,
      seq_scan,
      seq_tup_read,
      idx_scan,
      idx_tup_fetch,
      n_live_tup,
      pg_total_relation_size(schemaname||'.'||tablename) as table_size
    FROM pg_stat_user_tables
    WHERE schemaname = 'public'
      AND seq_scan > idx_scan
      AND n_live_tup > 10000
    ORDER BY seq_scan DESC
    LIMIT 20
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        stats =
          Enum.map(rows, fn [
                              schema,
                              table,
                              seq_scan,
                              seq_read,
                              idx_scan,
                              idx_fetch,
                              live_tup,
                              size
                            ] ->
            %{
              schema: schema,
              table: table,
              sequential_scans: seq_scan || 0,
              sequential_tuples_read: seq_read || 0,
              index_scans: idx_scan || 0,
              index_tuples_fetched: idx_fetch || 0,
              live_tuples: live_tup || 0,
              table_size: size,
              seq_scan_ratio: calculate_seq_scan_ratio(seq_scan, idx_scan)
            }
          end)

        {:ok, stats}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Analyze partition sizes and distribution.
  """
  def analyze_partition_distribution do
    query = """
    WITH partition_stats AS (
      SELECT
        parent.relname as parent_table,
        child.relname as partition_name,
        pg_relation_size(child.oid) as size_bytes,
        pg_stat_get_live_tuples(child.oid) as row_count,
        obj_description(child.oid) as description
      FROM pg_inherits
      JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
      JOIN pg_class child ON pg_inherits.inhrelid = child.oid
      WHERE parent.relnamespace = 'public'::regnamespace
    )
    SELECT
      parent_table,
      COUNT(*) as partition_count,
      SUM(size_bytes) as total_size,
      AVG(size_bytes) as avg_partition_size,
      MAX(size_bytes) as max_partition_size,
      MIN(size_bytes) as min_partition_size,
      SUM(row_count) as total_rows,
      AVG(row_count) as avg_rows_per_partition
    FROM partition_stats
    GROUP BY parent_table
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [
                            table,
                            count,
                            total_size,
                            avg_size,
                            max_size,
                            min_size,
                            total_rows,
                            avg_rows
                          ] ->
          %{
            table: table,
            partition_count: count,
            total_size: total_size,
            total_size_pretty: format_bytes(total_size),
            avg_partition_size: avg_size,
            avg_partition_size_pretty: format_bytes(round(avg_size)),
            max_partition_size: max_size,
            min_partition_size: min_size,
            size_variance: calculate_size_variance(max_size, min_size, avg_size),
            total_rows: total_rows,
            avg_rows_per_partition: round(avg_rows),
            distribution_quality: assess_distribution_quality(max_size, min_size, avg_size)
          }
        end)

      {:error, _} ->
        []
    end
  end

  @doc """
  Check for index bloat.
  """
  def analyze_index_bloat do
    query = """
    WITH index_bloat AS (
      SELECT
        schemaname,
        tablename,
        indexname,
        pg_relation_size(indexrelid) as actual_size,
        CASE WHEN indisprimary THEN 0
             ELSE CEIL(n_live_tup *
                      (SELECT avg_width FROM pg_stats
                       WHERE schemaname = 'public'
                       AND tablename = pg_stat_user_indexes.tablename
                       LIMIT 1) * 0.5)
        END as estimated_size
      FROM pg_stat_user_indexes
      JOIN pg_index ON indexrelid = pg_index.indexrelid
      JOIN pg_stat_user_tables USING (schemaname, tablename)
      WHERE schemaname = 'public'
    )
    SELECT
      schemaname,
      tablename,
      indexname,
      pg_size_pretty(actual_size) as actual_size,
      pg_size_pretty(estimated_size) as estimated_size,
      CASE WHEN estimated_size > 0
           THEN ROUND((actual_size - estimated_size)::numeric / estimated_size * 100, 2)
           ELSE 0
      END as bloat_percent
    FROM index_bloat
    WHERE actual_size > 10485760  -- Only indexes > 10MB
    ORDER BY actual_size - estimated_size DESC
    LIMIT 20
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [schema, table, index, actual, estimated, bloat_pct] ->
          %{
            schema: schema,
            table: table,
            index: index,
            actual_size: actual,
            estimated_size: estimated,
            bloat_percent: bloat_pct || 0,
            needs_reindex: (bloat_pct || 0) > 50
          }
        end)

      {:error, _} ->
        []
    end
  end

  # Private helper functions

  defp needs_vacuum?(row_count, last_vacuum, last_autovacuum) do
    cond do
      is_nil(last_vacuum) and is_nil(last_autovacuum) and row_count > 10_000 ->
        true

      row_count > 100_000 ->
        last_vacuum_time = last_vacuum || last_autovacuum

        if last_vacuum_time do
          days_since = DateTime.diff(DateTime.utc_now(), last_vacuum_time, :day)
          days_since > 7
        else
          true
        end

      true ->
        false
    end
  end

  defp calculate_index_efficiency(scans, reads, fetches) do
    cond do
      is_nil(scans) or scans == 0 -> 0.0
      is_nil(reads) or reads == 0 -> 0.0
      true -> Float.round(fetches / reads * 100, 2)
    end
  end

  defp calculate_seq_scan_ratio(seq_scans, idx_scans) do
    total = (seq_scans || 0) + (idx_scans || 0)

    if total > 0 do
      Float.round((seq_scans || 0) / total * 100, 2)
    else
      0.0
    end
  end

  defp find_unused_indexes(index_stats) do
    index_stats
    |> Enum.filter(&(&1.scans == 0 and not &1.is_primary))
    |> Enum.map(fn idx ->
      %{
        table: idx.table,
        index: idx.index,
        size: idx.size,
        recommendation: "Consider dropping unused index"
      }
    end)
  end

  defp find_inefficient_indexes(index_stats) do
    index_stats
    |> Enum.filter(&(&1.efficiency < 50 and &1.scans > 100))
    |> Enum.map(fn idx ->
      %{
        table: idx.table,
        index: idx.index,
        efficiency: idx.efficiency,
        scans: idx.scans,
        recommendation: "Index has low efficiency - consider rebuilding or redesigning"
      }
    end)
  end

  defp suggest_missing_indexes(table_stats) do
    table_stats
    |> Enum.filter(&(&1.seq_scan_ratio > 80 and &1.sequential_scans > 1000))
    |> Enum.map(fn stat ->
      %{
        table: stat.table,
        sequential_scans: stat.sequential_scans,
        seq_scan_ratio: stat.seq_scan_ratio,
        recommendation: "High sequential scan ratio - consider adding indexes"
      }
    end)
  end

  defp find_duplicate_indexes do
    query = """
    SELECT
      indrelid::regclass as table_name,
      array_agg(indexrelid::regclass) as duplicate_indexes
    FROM pg_index
    WHERE indrelid IN (
      SELECT indrelid FROM pg_index
      WHERE indrelid::regclass::text LIKE 'public.%'
      GROUP BY indrelid, indkey
      HAVING COUNT(*) > 1
    )
    GROUP BY indrelid, indkey
    HAVING COUNT(*) > 1
    """

    case SQL.query(EveDmv.Repo, query) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [table, indexes] ->
          %{
            table: table,
            duplicate_indexes: indexes,
            recommendation: "Duplicate indexes found - consider consolidating"
          }
        end)

      {:error, _} ->
        []
    end
  end

  defp generate_index_report(analysis) do
    %{
      summary: %{
        unused_indexes_count: length(analysis.unused_indexes),
        inefficient_indexes_count: length(analysis.inefficient_indexes),
        missing_indexes_count: length(analysis.missing_indexes),
        duplicate_indexes_count: length(analysis.duplicate_indexes),
        bloated_indexes_count: Enum.count(analysis.index_bloat, & &1.needs_reindex)
      },
      details: analysis,
      recommendations: compile_recommendations(analysis)
    }
  end

  defp compile_recommendations(analysis) do
    recommendations = []

    recommendations =
      if length(analysis.unused_indexes) > 0 do
        [
          "#{length(analysis.unused_indexes)} unused indexes found - review for removal"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if length(analysis.inefficient_indexes) > 0 do
        [
          "#{length(analysis.inefficient_indexes)} inefficient indexes detected - consider rebuilding"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if length(analysis.missing_indexes) > 0 do
        [
          "#{length(analysis.missing_indexes)} tables may benefit from additional indexes"
          | recommendations
        ]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Index configuration appears optimal"]
    else
      recommendations
    end
  end

  defp format_bytes(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_073_741_824 ->
        "#{Float.round(bytes / 1_073_741_824, 2)} GB"

      bytes >= 1_048_576 ->
        "#{Float.round(bytes / 1_048_576, 2)} MB"

      bytes >= 1024 ->
        "#{Float.round(bytes / 1024, 2)} KB"

      true ->
        "#{bytes} bytes"
    end
  end

  defp format_bytes(_), do: "0 bytes"

  defp calculate_size_variance(max_size, min_size, avg_size) when avg_size > 0 do
    variance = (max_size - min_size) / avg_size
    Float.round(variance, 2)
  end

  defp calculate_size_variance(_, _, _), do: 0.0

  defp assess_distribution_quality(max_size, min_size, avg_size) when avg_size > 0 do
    variance = calculate_size_variance(max_size, min_size, avg_size)

    cond do
      variance < 0.5 -> :excellent
      variance < 1.0 -> :good
      variance < 2.0 -> :fair
      true -> :poor
    end
  end

  defp assess_distribution_quality(_, _, _), do: :unknown
end
