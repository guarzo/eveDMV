defmodule EveDmv.Contexts.WormholeOperations.Infrastructure.WormholeDataProvider do
  @moduledoc """
  Data provider for wormhole-related information and caching.

  Provides temporary stub implementation to resolve Dialyzer errors.
  This module should be fully implemented as part of the wormhole operations feature.
  """

  @doc """
  Refresh wormhole data cache.
  """
  @spec refresh_cache() :: :ok | {:error, term()}
  def refresh_cache do
    # In real implementation would:
    # - Refresh wormhole type data
    # - Update mass limitations
    # - Cache system connections
    # - Update static data
    :ok
  end
end
