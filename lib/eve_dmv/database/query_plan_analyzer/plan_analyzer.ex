defmodule EveDmv.Database.QueryPlanAnalyzer.PlanAnalyzer do
  @moduledoc """
  Query execution plan parsing and analysis module.

  Handles parsing PostgreSQL JSON execution plans and extracting performance
  metrics including node types, expensive operations, and row estimation errors.
  """

  require Logger

  @doc """
  Analyzes a PostgreSQL execution plan from JSON format.

  Extracts key performance metrics including execution time, costs,
  node types, expensive operations, and row estimation accuracy.
  """
  def analyze_execution_plan(json_plan, execution_time) do
    plan = Jason.decode!(json_plan)
    root_node = List.first(plan)["Plan"]

    %{
      total_cost: root_node["Total Cost"],
      actual_time: root_node["Actual Total Time"],
      actual_rows: root_node["Actual Rows"],
      planned_rows: root_node["Plan Rows"],
      execution_time_ms: execution_time,
      node_types: extract_node_types(root_node),
      expensive_operations: find_expensive_operations(root_node),
      row_estimation_errors: calculate_row_estimation_errors(root_node)
    }
  end

  @doc """
  Extracts all node types from an execution plan tree.

  Recursively traverses the plan tree to collect all operation types
  for analysis of query execution patterns.
  """
  def extract_node_types(node, types \\ []) do
    current_type = node["Node Type"]
    types_with_current = [current_type | types]

    case node["Plans"] do
      nil ->
        types_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, types_with_current, &extract_node_types/2)
    end
  end

  @doc """
  Identifies expensive operations in an execution plan.

  Finds operations with high cost or execution time that may be
  performance bottlenecks requiring optimization.
  """
  def find_expensive_operations(node, expensive \\ []) do
    current_cost = node["Total Cost"] || 0
    actual_time = node["Actual Total Time"] || 0

    expensive_with_current =
      if current_cost > 1_000 or actual_time > 100 do
        [
          %{
            node_type: node["Node Type"],
            cost: current_cost,
            actual_time: actual_time,
            relation: node["Relation Name"]
          }
          | expensive
        ]
      else
        expensive
      end

    case node["Plans"] do
      nil ->
        expensive_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, expensive_with_current, &find_expensive_operations/2)
    end
  end

  @doc """
  Calculates row estimation errors in query planning.

  Identifies significant differences between planned and actual row counts
  which can indicate stale statistics or poor query planning.
  """
  def calculate_row_estimation_errors(node, errors \\ []) do
    actual_rows = node["Actual Rows"] || 0
    planned_rows = node["Plan Rows"] || 1

    error_ratio = if planned_rows > 0, do: actual_rows / planned_rows, else: 1.0

    errors_with_current =
      if abs(error_ratio - 1.0) > 0.5 and actual_rows > 10 do
        [
          %{
            node_type: node["Node Type"],
            planned_rows: planned_rows,
            actual_rows: actual_rows,
            error_ratio: error_ratio,
            relation: node["Relation Name"]
          }
          | errors
        ]
      else
        errors
      end

    case node["Plans"] do
      nil ->
        errors_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, errors_with_current, &calculate_row_estimation_errors/2)
    end
  end

  @doc """
  Analyzes plan complexity based on node count and nesting depth.
  """
  def analyze_plan_complexity(node) do
    %{
      total_nodes: count_total_nodes(node),
      max_depth: calculate_max_depth(node),
      complexity_score: calculate_complexity_score(node)
    }
  end

  @doc """
  Identifies sequential scan operations in the plan.

  Sequential scans can indicate missing indexes and performance issues.
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
              filter: node["Filter"]
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
  Identifies sort operations and their characteristics.

  Expensive sorts can often be optimized with appropriate indexes.
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
              actual_time: node["Actual Total Time"]
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
  Analyzes join operations and their efficiency.
  """
  def analyze_join_operations(node, joins \\ []) do
    join_info =
      case node["Node Type"] do
        join_type when join_type in ["Nested Loop", "Hash Join", "Merge Join"] ->
          [
            %{
              join_type: join_type,
              join_filter: node["Join Filter"],
              hash_condition: node["Hash Cond"],
              merge_condition: node["Merge Cond"],
              cost: node["Total Cost"],
              actual_time: node["Actual Total Time"],
              actual_rows: node["Actual Rows"]
            }
          ]

        _ ->
          []
      end

    joins_with_current = join_info ++ joins

    case node["Plans"] do
      nil ->
        joins_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, joins_with_current, &analyze_join_operations/2)
    end
  end

  @doc """
  Generates performance recommendations based on plan analysis.
  """
  def generate_plan_recommendations(analysis) do
    initial_recommendations = []

    # Row estimation errors
    statistics_recommendations =
      if length(analysis.row_estimation_errors) > 0 do
        [
          "Update table statistics with ANALYZE to improve query planning"
          | initial_recommendations
        ]
      else
        initial_recommendations
      end

    # Sequential scans
    scan_recommendations =
      if Enum.any?(analysis.node_types, &(&1 == "Seq Scan")) do
        [
          "Sequential scans detected - consider adding indexes for frequently queried columns"
          | statistics_recommendations
        ]
      else
        statistics_recommendations
      end

    # Expensive sorts
    sort_recommendations =
      if Enum.any?(analysis.expensive_operations, &(&1.node_type == "Sort")) do
        [
          "Expensive sort operations - consider adding indexes to avoid sorting"
          | scan_recommendations
        ]
      else
        scan_recommendations
      end

    # Nested loops with high cost
    join_recommendations =
      if Enum.any?(analysis.expensive_operations, &(&1.node_type == "Nested Loop")) do
        [
          "Expensive nested loop joins - consider optimizing join conditions or adding indexes"
          | sort_recommendations
        ]
      else
        sort_recommendations
      end

    join_recommendations
  end

  # Private helper functions

  defp count_total_nodes(node) do
    child_count =
      case node["Plans"] do
        nil -> 0
        plans when is_list(plans) -> Enum.sum(Enum.map(plans, &count_total_nodes/1))
      end

    1 + child_count
  end

  defp calculate_max_depth(node, current_depth \\ 0) do
    case node["Plans"] do
      nil ->
        current_depth

      plans when is_list(plans) ->
        plans
        |> Enum.map(&calculate_max_depth(&1, current_depth + 1))
        |> Enum.max()
    end
  end

  defp calculate_complexity_score(node) do
    total_nodes = count_total_nodes(node)
    max_depth = calculate_max_depth(node)

    # Simple complexity scoring based on nodes and depth
    base_score = total_nodes * 2
    depth_penalty = max_depth * 5

    base_score + depth_penalty
  end
end
