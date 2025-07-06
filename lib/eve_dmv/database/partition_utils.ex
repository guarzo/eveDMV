defmodule EveDmv.Database.PartitionUtils do
  @moduledoc """
  Utility functions for working with partitioned tables.

  Provides helpers for partition-aware queries and partition metadata.
  """

  alias EveDmv.Repo
  alias Ecto.Adapters.SQL

  @doc """
  Get the partition name for a specific date and table.
  """
  def partition_name_for_date(table, date) do
    year = date.year
    month = String.pad_leading(to_string(date.month), 2, "0")
    "#{table}_y#{year}m#{month}"
  end

  @doc """
  Get all partitions for a date range.
  """
  def partitions_for_date_range(table, start_date, end_date) do
    start_date
    |> Date.range(end_date)
    |> Enum.map(&Date.beginning_of_month/1)
    |> Enum.uniq()
    |> Enum.map(&partition_name_for_date(table, &1))
  end

  @doc """
  Check if a partition exists for a given date.
  """
  def partition_exists_for_date?(table, date) do
    partition_name = partition_name_for_date(table, date)
    partition_exists?(partition_name)
  end

  @doc """
  Get partition statistics for optimization insights.
  """
  def get_partition_stats(table) do
    query = """
    SELECT
      schemaname,
      tablename,
      pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
      pg_total_relation_size(schemaname||'.'||tablename) as size_bytes
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename LIKE $1
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    """

    pattern = "#{table}_y%"

    case SQL.query(Repo, query, [pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, fn [_schema, table_name, size, size_bytes] ->
          %{
            partition: table_name,
            size: size,
            size_bytes: size_bytes,
            month: extract_month_from_partition(table_name)
          }
        end)

      _ ->
        []
    end
  end

  @doc """
  Get row counts for each partition.
  """
  def get_partition_row_counts(table) do
    partitions = list_partitions(table)

    Enum.map(partitions, fn partition ->
      count = get_table_row_count(partition)

      %{
        partition: partition,
        row_count: count,
        month: extract_month_from_partition(partition)
      }
    end)
  end

  @doc """
  Find the optimal partition for a query based on date range.
  """
  def optimal_partitions_for_query(table, start_date, end_date) do
    required_partitions = partitions_for_date_range(table, start_date, end_date)
    existing_partitions = list_partitions(table)

    available_partitions = Enum.filter(required_partitions, &(&1 in existing_partitions))
    missing_partitions = required_partitions -- available_partitions

    %{
      available: available_partitions,
      missing: missing_partitions,
      query_hint: generate_partition_query_hint(available_partitions)
    }
  end

  @doc """
  Analyze partition performance and health.
  """
  def analyze_partition_health(table) do
    stats = get_partition_stats(table)
    row_counts = get_partition_row_counts(table)

    # Combine stats and row counts
    combined_stats =
      Enum.map(stats, fn stat ->
        row_data = Enum.find(row_counts, &(&1.partition == stat.partition)) || %{row_count: 0}
        Map.merge(stat, row_data)
      end)

    # Calculate health metrics
    total_size = Enum.sum(Enum.map(combined_stats, & &1.size_bytes))
    total_rows = Enum.sum(Enum.map(combined_stats, & &1.row_count))
    avg_size = if length(combined_stats) > 0, do: total_size / length(combined_stats), else: 0

    # Identify problematic partitions
    oversized_partitions = Enum.filter(combined_stats, &(&1.size_bytes > avg_size * 2))
    empty_partitions = Enum.filter(combined_stats, &(&1.row_count == 0))

    %{
      total_partitions: length(combined_stats),
      total_size_bytes: total_size,
      total_rows: total_rows,
      average_size_bytes: avg_size,
      oversized_partitions: oversized_partitions,
      empty_partitions: empty_partitions,
      health_score: calculate_health_score(combined_stats),
      recommendations:
        generate_recommendations(combined_stats, oversized_partitions, empty_partitions)
    }
  end

  # Private helper functions

  defp partition_exists?(partition_name) do
    query = """
    SELECT EXISTS (
      SELECT 1 FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = $1
    )
    """

    case SQL.query(Repo, query, [partition_name]) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end

  defp list_partitions(table) do
    query = """
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
    AND tablename LIKE $1
    ORDER BY tablename
    """

    pattern = "#{table}_y%"

    case SQL.query(Repo, query, [pattern]) do
      {:ok, %{rows: rows}} ->
        Enum.map(rows, &Enum.at(&1, 0))

      _ ->
        []
    end
  end

  defp get_table_row_count(table_name) do
    query = "SELECT COUNT(*) FROM #{table_name}"

    case SQL.query(Repo, query, []) do
      {:ok, %{rows: [[count]]}} -> count
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp extract_month_from_partition(partition_name) do
    case Regex.run(~r/_y(\d{4})m(\d{2})$/, partition_name) do
      [_, year_str, month_str] ->
        year = String.to_integer(year_str)
        month = String.to_integer(month_str)
        Date.new!(year, month, 1)

      _ ->
        nil
    end
  end

  defp generate_partition_query_hint(partitions) do
    if length(partitions) <= 3 do
      "Query will scan #{length(partitions)} partition(s): #{Enum.join(partitions, ", ")}"
    else
      first_two_partitions =
        Enum.take(partitions, 2)
        |> Enum.join(", ")

      "Query will scan #{length(partitions)} partitions (#{first_two_partitions}, ...)"
    end
  end

  defp calculate_health_score(partition_stats) do
    if Enum.empty?(partition_stats) do
      0
    else
      # Calculate based on size distribution and row counts
      sizes = Enum.map(partition_stats, & &1.size_bytes)
      avg_size = Enum.sum(sizes) / length(sizes)
      size_variance = calculate_variance(sizes, avg_size)

      # Lower variance = better health score
      # Normalize to 0-100 scale
      # Max expected variance
      max_variance = avg_size * avg_size
      normalized_variance = min(size_variance / max_variance, 1.0)

      round((1.0 - normalized_variance) * 100)
    end
  end

  defp calculate_variance(values, mean) do
    if Enum.empty?(values) do
      0
    else
      sum_of_squares = Enum.sum(Enum.map(values, &((&1 - mean) * (&1 - mean))))
      sum_of_squares / length(values)
    end
  end

  defp generate_recommendations(partition_stats, oversized_partitions, empty_partitions) do
    recommendations = []

    recommendations =
      if Enum.empty?(empty_partitions) do
        recommendations
      else
        [
          "Consider dropping #{length(empty_partitions)} empty partitions to save space"
          | recommendations
        ]
      end

    recommendations =
      if length(oversized_partitions) > 0 do
        [
          "Monitor #{length(oversized_partitions)} oversized partitions for performance impact"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations =
      if length(partition_stats) > 36 do
        [
          "Consider implementing automatic cleanup for partitions older than 3 years"
          | recommendations
        ]
      else
        recommendations
      end

    if Enum.empty?(recommendations) do
      ["Partition health is good - no immediate action required"]
    else
      recommendations
    end
  end
end
