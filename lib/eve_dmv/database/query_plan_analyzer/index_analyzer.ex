defmodule EveDmv.Database.QueryPlanAnalyzer.IndexAnalyzer do
  @moduledoc """
  Index usage analysis module for PostgreSQL query plans.

  Analyzes index usage patterns, identifies missing indexes, and provides
  optimization recommendations for query performance improvement.
  """

  require Logger

  @doc """
  Extracts index usage information from an execution plan node.

  Recursively traverses the plan tree to collect all index scan operations
  including regular index scans, index-only scans, and bitmap index scans.
  """
  def extract_index_usage(node, indexes \\ []) do
    index_info =
      case node["Node Type"] do
        "Index Scan" ->
          [
            %{
              type: "Index Scan",
              index_name: node["Index Name"],
              relation: node["Relation Name"],
              cost: node["Total Cost"],
              rows: node["Actual Rows"],
              actual_time: node["Actual Total Time"],
              index_condition: node["Index Cond"],
              filter: node["Filter"]
            }
          ]

        "Index Only Scan" ->
          [
            %{
              type: "Index Only Scan",
              index_name: node["Index Name"],
              relation: node["Relation Name"],
              cost: node["Total Cost"],
              rows: node["Actual Rows"],
              actual_time: node["Actual Total Time"],
              index_condition: node["Index Cond"],
              heap_fetches: node["Heap Fetches"]
            }
          ]

        "Bitmap Index Scan" ->
          [
            %{
              type: "Bitmap Index Scan",
              index_name: node["Index Name"],
              relation: node["Relation Name"],
              cost: node["Total Cost"],
              rows: node["Actual Rows"],
              actual_time: node["Actual Total Time"],
              index_condition: node["Index Cond"]
            }
          ]

        _ ->
          []
      end

    indexes_with_current = index_info ++ indexes

    case node["Plans"] do
      nil ->
        indexes_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, indexes_with_current, &extract_index_usage/2)
    end
  end

  @doc """
  Analyzes index usage patterns and effectiveness.

  Examines index usage statistics to identify underutilized indexes,
  missing indexes, and optimization opportunities.
  """
  def analyze_index_patterns(index_usage) do
    %{
      total_index_operations: length(index_usage),
      index_types: count_index_types(index_usage),
      index_efficiency: calculate_index_efficiency(index_usage),
      potentially_unused_indexes: find_potentially_unused_indexes(index_usage),
      high_cost_indexes: find_high_cost_indexes(index_usage)
    }
  end

  @doc """
  Generates index optimization recommendations based on usage analysis.
  """
  def generate_index_recommendations(analysis, sequential_scans \\ []) do
    base_recommendations = []

    # Missing indexes for sequential scans
    scan_index_recommendations =
      if length(sequential_scans) > 0 do
        scan_suggestions =
          sequential_scans
          |> Enum.map(&suggest_index_for_scan/1)
          |> Enum.reject(&is_nil/1)

        scan_suggestions ++ base_recommendations
      else
        base_recommendations
      end

    # Index-only scan opportunities
    covering_index_recommendations =
      if has_regular_index_scans_with_heap_fetches(analysis) do
        [
          "Consider covering indexes to enable index-only scans and reduce heap fetches"
          | scan_index_recommendations
        ]
      else
        scan_index_recommendations
      end

    # Bitmap scan optimization
    bitmap_scan_recommendations =
      if has_expensive_bitmap_scans(analysis) do
        [
          "Expensive bitmap index scans detected - consider composite indexes or query restructuring"
          | covering_index_recommendations
        ]
      else
        covering_index_recommendations
      end

    # Unused index cleanup
    cleanup_recommendations =
      if length(analysis.potentially_unused_indexes) > 0 do
        [
          "Consider removing unused indexes: #{Enum.join(analysis.potentially_unused_indexes, ", ")}"
          | bitmap_scan_recommendations
        ]
      else
        bitmap_scan_recommendations
      end

    cleanup_recommendations
  end

  @doc """
  Identifies sequential scan operations that could benefit from indexes.
  """
  def find_sequential_scans(node, scans \\ []) do
    scan_info =
      case node["Node Type"] do
        "Seq Scan" ->
          [
            %{
              relation: node["Relation Name"],
              cost: node["Total Cost"],
              actual_time: node["Actual Total Time"],
              rows_scanned: node["Actual Rows"],
              filter: node["Filter"],
              rows_removed: node["Rows Removed by Filter"]
            }
          ]

        _ ->
          []
      end

    scans_with_current = scan_info ++ scans

    case node["Plans"] do
      nil ->
        scans_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, scans_with_current, &find_sequential_scans/2)
    end
  end

  @doc """
  Analyzes sort operations that could benefit from indexes.
  """
  def find_sort_operations(node, sorts \\ []) do
    sort_info =
      case node["Node Type"] do
        "Sort" ->
          [
            %{
              sort_key: node["Sort Key"],
              sort_method: node["Sort Method"],
              sort_space_used: node["Sort Space Used"],
              sort_space_type: node["Sort Space Type"],
              cost: node["Total Cost"],
              actual_time: node["Actual Total Time"],
              rows: node["Actual Rows"]
            }
          ]

        _ ->
          []
      end

    sorts_with_current = sort_info ++ sorts

    case node["Plans"] do
      nil ->
        sorts_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, sorts_with_current, &find_sort_operations/2)
    end
  end

  @doc """
  Suggests specific index creation statements based on query patterns.
  """
  def suggest_index_creation(table, columns, scan_info) do
    filter_selectivity = calculate_filter_selectivity(scan_info)

    index_type =
      cond do
        length(columns) == 1 -> "btree"
        has_range_conditions(scan_info) -> "btree"
        has_equality_conditions_only(scan_info) -> "hash"
        true -> "btree"
      end

    column_list = Enum.join(columns, ", ")

    %{
      sql:
        "CREATE INDEX CONCURRENTLY idx_#{table}_#{Enum.join(columns, "_")} ON #{table} USING #{index_type} (#{column_list});",
      estimated_benefit: estimate_index_benefit(scan_info, filter_selectivity),
      reasoning: build_index_reasoning(scan_info, columns, filter_selectivity)
    }
  end

  @doc """
  Analyzes index bloat and maintenance overhead.
  """
  def analyze_index_health(index_usage) do
    Enum.map(index_usage, fn index ->
      %{
        index_name: index.index_name,
        usage_frequency: calculate_usage_frequency(index),
        efficiency_score: calculate_efficiency_score(index),
        maintenance_overhead: estimate_maintenance_overhead(index),
        health_status: determine_health_status(index)
      }
    end)
  end

  # Private helper functions

  defp count_index_types(index_usage) do
    index_usage
    |> Enum.group_by(& &1.type)
    |> Enum.into(%{}, fn {type, indexes} -> {type, length(indexes)} end)
  end

  defp calculate_index_efficiency(index_usage) do
    if index_usage == [] do
      0.0
    else
      total_efficiency =
        index_usage
        |> Enum.map(&calculate_single_index_efficiency/1)
        |> Enum.sum()

      total_efficiency / length(index_usage)
    end
  end

  defp calculate_single_index_efficiency(index) do
    # Simple efficiency calculation based on cost vs rows returned
    if index.cost > 0 and index.rows > 0 do
      index.rows / index.cost * 100
    else
      0.0
    end
  end

  defp find_potentially_unused_indexes(index_usage) do
    index_usage
    |> Enum.filter(fn index ->
      # Consider an index potentially unused if it has very high cost relative to rows
      index.cost > 1_000 and index.rows < 10
    end)
    |> Enum.map(& &1.index_name)
    |> Enum.uniq()
  end

  defp find_high_cost_indexes(index_usage) do
    index_usage
    |> Enum.filter(&(&1.cost > 1_000))
    |> Enum.sort_by(& &1.cost, :desc)
  end

  defp suggest_index_for_scan(scan) do
    if scan.filter and scan.rows_scanned > 1_000 do
      # Extract column names from filter condition (simplified)
      columns = extract_columns_from_filter(scan.filter)

      if length(columns) > 0 do
        "CREATE INDEX ON #{scan.relation} (#{Enum.join(columns, ", ")}) -- for filter: #{scan.filter}"
      end
    end
  end

  defp extract_columns_from_filter(filter) when is_binary(filter) do
    # Very simplified column extraction - in practice this would need more sophisticated parsing
    filter
    |> String.split(~r/[=<>!\s]+/)
    |> Enum.filter(fn part ->
      String.match?(part, ~r/^[a-zA-Z][a-zA-Z0-9_]*$/) and
        not String.match?(part, ~r/^(AND|OR|NOT|NULL|TRUE|FALSE)$/i)
    end)
    # Limit to 3 columns for composite index
    |> Enum.take(3)
  end

  defp extract_columns_from_filter(_), do: []

  defp has_regular_index_scans_with_heap_fetches(analysis) do
    Map.get(analysis.index_types, "Index Only Scan", 0) == 0 and
      Map.get(analysis.index_types, "Index Scan", 0) > 0
  end

  defp has_expensive_bitmap_scans(analysis) do
    Map.get(analysis.index_types, "Bitmap Index Scan", 0) > 0 and
      length(analysis.high_cost_indexes) > 0
  end

  defp calculate_filter_selectivity(scan_info) do
    if scan_info.rows_removed && scan_info.rows_scanned > 0 do
      (scan_info.rows_scanned - scan_info.rows_removed) / scan_info.rows_scanned
    else
      # Default moderate selectivity
      0.5
    end
  end

  defp has_range_conditions(scan_info) do
    filter = scan_info.filter || ""
    String.contains?(filter, ["<", ">", "BETWEEN", ">=", "<="])
  end

  defp has_equality_conditions_only(scan_info) do
    filter = scan_info.filter || ""
    String.contains?(filter, "=") and not has_range_conditions(scan_info)
  end

  defp estimate_index_benefit(scan_info, selectivity) do
    # Estimated 80% reduction
    cost_reduction = scan_info.cost * selectivity * 0.8

    cond do
      cost_reduction > 1_000 -> "High"
      cost_reduction > 100 -> "Medium"
      cost_reduction > 10 -> "Low"
      true -> "Minimal"
    end
  end

  defp build_index_reasoning(scan_info, columns, selectivity) do
    "Sequential scan on #{scan_info.relation} with #{length(columns)} column filter " <>
      "(selectivity: #{Float.round(selectivity * 100, 1)}%). " <>
      "Index could reduce cost from #{scan_info.cost} significantly."
  end

  defp calculate_usage_frequency(_index) do
    # In practice, this would track how often the index is used
    # For now, return a placeholder value
    "Unknown"
  end

  defp calculate_efficiency_score(index) do
    if index.cost > 0 and index.rows > 0 do
      # Simple efficiency: rows returned per unit cost
      index.rows / index.cost * 100
    else
      0.0
    end
  end

  defp estimate_maintenance_overhead(_index) do
    # Placeholder - would consider index size, update frequency, etc.
    "Medium"
  end

  defp determine_health_status(index) do
    efficiency = calculate_efficiency_score(index)

    cond do
      efficiency > 10 -> "Healthy"
      efficiency > 1 -> "Fair"
      efficiency > 0.1 -> "Poor"
      true -> "Critical"
    end
  end
end
