defmodule EveDmv.IntelligenceEngine.Plugin do
  @moduledoc """
  Behaviour for Intelligence Engine plugins.

  This defines the contract that all plugins must implement for
  backward compatibility with the old plugin system.
  """

  @doc """
  Returns plugin metadata including name, description, version, and dependencies.
  """
  @callback plugin_info() :: %{
              name: String.t(),
              description: String.t(),
              version: String.t(),
              dependencies: [atom()]
            }

  @doc """
  Analyze an entity using this plugin.

  Args:
    - entity_id: The entity to analyze
    - base_data: Base analysis data structure
    - opts: Analysis options

  Returns:
    - {:ok, result} on successful analysis
    - {:error, reason} on failure
  """
  @callback analyze(entity_id :: integer(), base_data :: map(), opts :: keyword()) ::
              {:ok, map()} | {:error, any()}

  @doc """
  Whether this plugin supports batch analysis of multiple entities.
  """
  @callback supports_batch?() :: boolean()

  @doc """
  List of other plugins this plugin depends on.
  """
  @callback dependencies() :: [atom()]

  @doc """
  Cache strategy configuration for this plugin.
  """
  @callback cache_strategy() :: %{
              ttl_seconds: non_neg_integer(),
              invalidate_on: [atom()]
            }

  @optional_callbacks [supports_batch?: 0, dependencies: 0, cache_strategy: 0]
end
