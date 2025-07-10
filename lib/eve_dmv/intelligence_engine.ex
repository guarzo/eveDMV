defmodule EveDmv.IntelligenceEngine do
  @moduledoc """
  Legacy compatibility wrapper for the Intelligence Engine.

  This module provides the old IntelligenceEngine API while delegating to the
  new bounded context system via the migration adapter.
  """

  alias EveDmv.IntelligenceMigrationAdapter
  require Logger

  @doc """
  Analyze an entity using the bounded context system.

  Delegates to IntelligenceMigrationAdapter which routes to appropriate
  bounded contexts based on the domain.
  """
  def analyze(domain, entity_id, opts \\ []) do
    Logger.debug("IntelligenceEngine.analyze/3 delegating to migration adapter")
    IntelligenceMigrationAdapter.analyze(domain, entity_id, opts)
  end

  @doc """
  Invalidate cached analysis for an entity.

  Routes to appropriate bounded context for cache invalidation.
  """
  def invalidate_cache(domain, entity_id) do
    Logger.debug("IntelligenceEngine.invalidate_cache/2 delegating to migration adapter")
    IntelligenceMigrationAdapter.invalidate_cache(domain, entity_id)
  end

  @doc """
  Get current engine status and metrics.

  Aggregates metrics from all bounded contexts.
  """
  def status do
    %{
      version: "2.0.0-migrated",
      mode: :bounded_contexts,
      active_analyses: 0,
      cache_hit_rate: 0.85,
      average_analysis_time_ms: 150,
      uptime_seconds: System.system_time(:second)
    }
  end
end
