defmodule EveDmv.Database.QueryPlanAnalyzer.BufferAnalyzer do
  @moduledoc """
  Buffer usage analysis module for PostgreSQL query plans.
  
  Analyzes shared buffer usage, cache hit ratios, and temporary file usage
  to identify I/O bottlenecks and memory optimization opportunities.
  """

  require Logger

  @doc """
  Extracts buffer usage statistics from an execution plan node.
  
  Recursively traverses the plan tree to collect all buffer usage metrics
  including shared blocks read/hit and temporary blocks read/written.
  """
  def extract_buffer_usage(node, usage \\ %{}) do
    shared_hit = node["Shared Hit Blocks"] || 0
    shared_read = node["Shared Read Blocks"] || 0
    temp_read = node["Temp Read Blocks"] || 0
    temp_written = node["Temp Written Blocks"] || 0

    current_usage = %{
      shared_hit: shared_hit,
      shared_read: shared_read,
      temp_read: temp_read,
      temp_written: temp_written,
      cache_hit_ratio:
        if(shared_hit + shared_read > 0,
          do: shared_hit / (shared_hit + shared_read),
          else: 1.0
        )
    }

    merged_usage = merge_buffer_usage(usage, current_usage)

    case node["Plans"] do
      nil ->
        merged_usage

      plans when is_list(plans) ->
        Enum.reduce(plans, merged_usage, &extract_buffer_usage/2)
    end
  end

  @doc """
  Merges buffer usage statistics from multiple nodes.
  
  Combines buffer usage metrics from different parts of the query plan
  to provide overall buffer usage analysis.
  """
  def merge_buffer_usage(usage1, usage2) do
    %{
      shared_hit: (usage1[:shared_hit] || 0) + usage2.shared_hit,
      shared_read: (usage1[:shared_read] || 0) + usage2.shared_read,
      temp_read: (usage1[:temp_read] || 0) + usage2.temp_read,
      temp_written: (usage1[:temp_written] || 0) + usage2.temp_written,
      cache_hit_ratio: calculate_combined_cache_ratio(usage1, usage2)
    }
  end

  @doc """
  Calculates the overall cache hit ratio from combined buffer usage.
  
  Provides accurate cache hit ratio calculation when merging buffer
  statistics from multiple query plan nodes.
  """
  def calculate_combined_cache_ratio(usage1, usage2) do
    total_hit = (usage1[:shared_hit] || 0) + usage2.shared_hit
    total_read = (usage1[:shared_read] || 0) + usage2.shared_read

    if total_hit + total_read > 0 do
      total_hit / (total_hit + total_read)
    else
      1.0
    end
  end

  @doc """
  Analyzes buffer usage patterns and identifies potential issues.
  
  Examines buffer usage metrics to detect I/O bottlenecks, memory pressure,
  and opportunities for performance optimization.
  """
  def analyze_buffer_patterns(buffer_usage) do
    analysis = %{
      total_blocks_accessed: buffer_usage.shared_hit + buffer_usage.shared_read,
      cache_efficiency: buffer_usage.cache_hit_ratio,
      temp_file_usage: buffer_usage.temp_read + buffer_usage.temp_written,
      memory_pressure_indicators: []
    }

    analysis = add_cache_efficiency_assessment(analysis, buffer_usage)
    analysis = add_temp_usage_assessment(analysis, buffer_usage)
    analysis = add_memory_pressure_indicators(analysis, buffer_usage)

    analysis
  end

  @doc """
  Generates buffer optimization recommendations based on usage patterns.
  """
  def generate_buffer_recommendations(buffer_usage) do
    recommendations = []

    # Low cache hit ratio
    recommendations =
      if buffer_usage.cache_hit_ratio < 0.9 do
        [
          "Consider increasing shared_buffers or optimizing query to reduce disk I/O"
          | recommendations
        ]
      else
        recommendations
      end

    # High temp file usage
    recommendations =
      if buffer_usage.temp_read + buffer_usage.temp_written > 1000 do
        [
          "High temporary file usage detected - consider increasing work_mem or temp_buffers"
          | recommendations
        ]
      else
        recommendations
      end

    # Very low cache hit ratio
    recommendations =
      if buffer_usage.cache_hit_ratio < 0.5 do
        [
          "Critical: Very low cache hit ratio indicates severe I/O bottleneck"
          | recommendations
        ]
      else
        recommendations
      end

    recommendations
  end

  @doc """
  Identifies buffer usage hotspots in the query plan.
  
  Finds nodes with high buffer usage that may be performance bottlenecks.
  """
  def find_buffer_hotspots(node, hotspots \\ []) do
    shared_hit = node["Shared Hit Blocks"] || 0
    shared_read = node["Shared Read Blocks"] || 0
    total_blocks = shared_hit + shared_read

    hotspot_info =
      if total_blocks > 1000 do
        [
          %{
            node_type: node["Node Type"],
            relation: node["Relation Name"],
            shared_hit: shared_hit,
            shared_read: shared_read,
            total_blocks: total_blocks,
            cache_hit_ratio:
              if(total_blocks > 0, do: shared_hit / total_blocks, else: 1.0)
          }
        ]
      else
        []
      end

    hotspots_with_current = hotspot_info ++ hotspots

    case node["Plans"] do
      nil ->
        hotspots_with_current

      plans when is_list(plans) ->
        Enum.reduce(plans, hotspots_with_current, &find_buffer_hotspots/2)
    end
  end

  @doc """
  Estimates I/O cost based on buffer usage patterns.
  """
  def estimate_io_cost(buffer_usage) do
    # Simple I/O cost estimation based on shared buffer misses
    shared_read_cost = buffer_usage.shared_read * 10  # Arbitrary cost per read
    temp_io_cost = (buffer_usage.temp_read + buffer_usage.temp_written) * 5

    %{
      shared_read_cost: shared_read_cost,
      temp_io_cost: temp_io_cost,
      total_estimated_cost: shared_read_cost + temp_io_cost,
      efficiency_score: buffer_usage.cache_hit_ratio * 100
    }
  end

  # Private helper functions

  defp add_cache_efficiency_assessment(analysis, buffer_usage) do
    efficiency_level =
      cond do
        buffer_usage.cache_hit_ratio >= 0.95 -> "Excellent"
        buffer_usage.cache_hit_ratio >= 0.90 -> "Good"
        buffer_usage.cache_hit_ratio >= 0.80 -> "Fair"
        buffer_usage.cache_hit_ratio >= 0.60 -> "Poor"
        true -> "Critical"
      end

    Map.put(analysis, :cache_efficiency_level, efficiency_level)
  end

  defp add_temp_usage_assessment(analysis, buffer_usage) do
    temp_usage_level =
      cond do
        buffer_usage.temp_read + buffer_usage.temp_written == 0 -> "None"
        buffer_usage.temp_read + buffer_usage.temp_written < 100 -> "Low"
        buffer_usage.temp_read + buffer_usage.temp_written < 1000 -> "Moderate"
        buffer_usage.temp_read + buffer_usage.temp_written < 10000 -> "High"
        true -> "Excessive"
      end

    Map.put(analysis, :temp_usage_level, temp_usage_level)
  end

  defp add_memory_pressure_indicators(analysis, buffer_usage) do
    indicators = []

    indicators =
      if buffer_usage.temp_written > 0 do
        ["Temporary data spilled to disk" | indicators]
      else
        indicators
      end

    indicators =
      if buffer_usage.cache_hit_ratio < 0.8 do
        ["Low cache hit ratio indicates memory pressure" | indicators]
      else
        indicators
      end

    indicators =
      if buffer_usage.temp_read + buffer_usage.temp_written > 5000 do
        ["Excessive temporary file I/O" | indicators]
      else
        indicators
      end

    Map.put(analysis, :memory_pressure_indicators, indicators)
  end
end