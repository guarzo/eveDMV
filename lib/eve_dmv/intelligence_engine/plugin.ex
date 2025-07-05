defmodule EveDmv.IntelligenceEngine.Plugin do
  @moduledoc """
  Behavior for Intelligence Engine plugins.

  Defines the standard interface that all intelligence analysis plugins must implement.
  This behavior ensures consistent interfaces, proper error handling, and standardized
  metadata across all plugins in the Intelligence Engine.

  ## Plugin Interface

  All plugins must implement:
  - `analyze/3` - Core analysis function
  - `plugin_info/0` - Plugin metadata and configuration

  Optional callbacks for advanced functionality:
  - `supports_batch?/0` - Whether plugin supports batch analysis
  - `dependencies/0` - Plugin dependencies
  - `cache_strategy/0` - Custom caching behavior

  ## Example Plugin

      defmodule MyPlugin do
        use EveDmv.IntelligenceEngine.Plugin
        
        @impl true
        def analyze(entity_id, base_data, opts) do
          # Plugin-specific analysis logic
          {:ok, %{analysis_result: "data"}}
        end
        
        @impl true  
        def plugin_info do
          %{
            name: "My Custom Plugin",
            description: "Does amazing analysis",
            version: "1.0.0",
            dependencies: []
          }
        end
      end

  ## Plugin Categories

  Plugins are organized into domains:
  - **Character Plugins**: Individual pilot analysis
  - **Corporation Plugins**: Organization-level analysis  
  - **Fleet Plugins**: Fleet composition and tactical analysis
  - **Threat Plugins**: Security and risk assessment
  """

  @type entity_id :: integer()
  @type entity_ids :: [integer()]
  @type base_data :: map()
  @type plugin_options :: keyword()
  @type analysis_result :: map()
  @type plugin_info :: %{
          required(:name) => String.t(),
          required(:description) => String.t(),
          required(:version) => String.t(),
          required(:dependencies) => [atom() | {atom(), atom()}],
          # Allow additional fields like :author, :tags, etc.
          optional(atom()) => term()
        }

  @doc """
  Core analysis function that all plugins must implement.

  ## Parameters

  - `entity_id_or_ids` - Single entity ID or list of entity IDs to analyze
  - `base_data` - Pre-gathered base data from the pipeline (killmails, character stats, etc.)
  - `opts` - Plugin-specific options and configuration

  ## Returns

  - `{:ok, analysis_result}` - Successful analysis with results map
  - `{:error, reason}` - Analysis failed with error reason

  ## Examples

      # Single entity analysis
      analyze(98765, %{character_stats: %{...}, killmail_stats: %{...}}, [])
      
      # Batch analysis
      analyze([98765, 98766], %{character_stats: %{...}}, parallel: true)
  """
  @callback analyze(entity_id() | entity_ids(), base_data(), plugin_options()) ::
              {:ok, analysis_result()} | {:error, term()}

  @doc """
  Plugin metadata and configuration information.

  Returns a map with plugin details used by the Intelligence Engine
  for plugin management, dependency resolution, and documentation.

  ## Required Fields

  - `:name` - Human-readable plugin name
  - `:description` - Brief description of plugin functionality
  - `:version` - Plugin version string
  - `:dependencies` - List of plugin dependencies

  ## Optional Fields

  - `:author` - Plugin author information
  - `:license` - Plugin license
  - `:homepage` - Plugin documentation URL
  - `:tags` - List of tags for categorization
  - `:config_schema` - JSON schema for plugin configuration

  ## Examples

      def plugin_info do
        %{
          name: "Combat Statistics Analyzer",
          description: "Analyzes character combat performance and patterns",
          version: "2.1.0",
          dependencies: [:eve_database],
          tags: [:character, :combat, :statistics],
          author: "EVE DMV Team"
        }
      end
  """
  @callback plugin_info() :: plugin_info()

  @doc """
  Whether this plugin supports batch analysis of multiple entities.

  Plugins that return `true` can efficiently process multiple entity IDs
  in a single call, which can provide significant performance benefits.

  Default implementation returns `false`.
  """
  @callback supports_batch?() :: boolean()

  @doc """
  List of dependencies required by this plugin.

  Dependencies can be:
  - `:module_name` - Elixir module dependency
  - `{:application, :app_name}` - Application dependency
  - `{:plugin, :plugin_name}` - Other plugin dependency

  Default implementation returns an empty list.
  """
  @callback dependencies() :: [atom() | {atom(), atom()}]

  @doc """
  Custom cache strategy for this plugin.

  Allows plugins to define custom caching behavior beyond the default
  pipeline caching. Returns cache configuration map.

  Default implementation uses standard pipeline caching.
  """
  @callback cache_strategy() :: map()

  @optional_callbacks [supports_batch?: 0, dependencies: 0, cache_strategy: 0]

  defmacro __using__(_opts) do
    quote do
      @behaviour EveDmv.IntelligenceEngine.Plugin

      require Logger

      @doc """
      Default implementation for batch support check.
      Override to enable batch processing.
      """
      def supports_batch?, do: false

      @doc """
      Default implementation for dependencies.
      Override to specify plugin dependencies.
      """
      def dependencies, do: []

      @doc """
      Default implementation for cache strategy.
      Override to customize caching behavior.
      """
      def cache_strategy do
        %{
          strategy: :default,
          ttl_seconds: 600,
          cache_key_prefix: nil
        }
      end

      defoverridable supports_batch?: 0, dependencies: 0, cache_strategy: 0

      # Helper functions available to all plugins

      @doc """
      Helper to safely extract character data from base_data.
      """
      def get_character_data(base_data, character_id) do
        case get_in(base_data, [:character_stats, character_id]) do
          nil -> {:error, :character_not_found}
          character_stats -> {:ok, character_stats}
        end
      end

      @doc """
      Helper to safely extract killmail statistics from base_data.
      """
      def get_killmail_stats(base_data, character_id) do
        case get_in(base_data, [:killmail_stats, character_id]) do
          # Default to empty stats if not available
          nil -> {:ok, %{}}
          stats -> {:ok, stats}
        end
      end

      @doc """
      Helper to validate required options are present.
      """
      def validate_required_opts(opts, required_keys) do
        missing_keys =
          required_keys
          |> Enum.filter(fn key -> not Keyword.has_key?(opts, key) end)

        case missing_keys do
          [] -> :ok
          keys -> {:error, {:missing_required_options, keys}}
        end
      end

      @doc """
      Helper to log plugin execution with consistent format.
      """
      def log_plugin_execution(entity_id, duration_ms, result) do
        plugin_name = __MODULE__ |> Module.split() |> List.last()

        case result do
          {:ok, _} ->
            Logger.debug("Plugin execution completed",
              plugin: plugin_name,
              entity_id: entity_id,
              duration_ms: duration_ms
            )

          {:error, reason} ->
            Logger.warning("Plugin execution failed",
              plugin: plugin_name,
              entity_id: entity_id,
              duration_ms: duration_ms,
              reason: inspect(reason)
            )
        end
      end

      @doc """
      Helper to handle plugin exceptions consistently.
      """
      def handle_plugin_exception(exception, entity_id) do
        plugin_name = __MODULE__ |> Module.split() |> List.last()

        Logger.error("Plugin exception occurred",
          plugin: plugin_name,
          entity_id: entity_id,
          exception: inspect(exception)
        )

        {:error, {:plugin_exception, exception}}
      end

      @doc """
      Helper to merge results from batch operations.
      """
      def merge_batch_results(results) when is_list(results) do
        successful_results =
          results
          |> Enum.filter(fn {_id, result} -> match?({:ok, _}, result) end)
          |> Enum.into(%{}, fn {id, {:ok, result}} -> {id, result} end)

        failed_results =
          results
          |> Enum.filter(fn {_id, result} -> match?({:error, _}, result) end)
          |> Enum.into(%{}, fn {id, {:error, reason}} -> {id, reason} end)

        %{
          successful: successful_results,
          failed: failed_results,
          total_count: length(results),
          success_count: map_size(successful_results),
          failure_count: map_size(failed_results)
        }
      end
    end
  end
end
