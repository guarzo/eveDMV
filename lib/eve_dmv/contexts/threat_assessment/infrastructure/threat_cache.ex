defmodule EveDmv.Contexts.ThreatAssessment.Infrastructure.ThreatCache do
  @moduledoc """
  Threat assessment cache infrastructure stub.

  This module was removed during namespace consolidation.
  Caching functionality has been moved to the unified cache system.
  """

  require Logger

  @doc """
  Invalidate entity cache - stub implementation.
  """
  def invalidate_entity(entity_type, entity_id) do
    Logger.info(
      "ThreatCache.invalidate_entity/2 called for #{entity_type}:#{entity_id} - functionality moved to unified cache"
    )

    :ok
  end

  @doc """
  Clear threat caches - stub implementation.
  """
  def clear_all do
    Logger.info("ThreatCache.clear_all/0 called - functionality moved to unified cache")
    :ok
  end
end
