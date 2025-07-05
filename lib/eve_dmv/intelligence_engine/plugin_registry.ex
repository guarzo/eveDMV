defmodule EveDmv.IntelligenceEngine.PluginRegistry do
  @moduledoc """
  Plugin registry for managing Intelligence Engine analyzers.

  Maintains a registry of available plugins organized by analysis domain
  and provides plugin discovery, validation, and lifecycle management.

  ## Plugin Organization

  Plugins are organized by analysis domains:
  - `:character` - Individual character analysis plugins
  - `:corporation` - Corporation-level analysis plugins
  - `:fleet` - Fleet composition and tactical analysis plugins
  - `:threat` - Threat assessment and security analysis plugins

  ## Plugin Validation

  All plugins must implement the `EveDmv.IntelligenceEngine.Plugin` behavior
  and pass validation checks during registration.
  """

  use GenServer
  require Logger

  @type domain :: :character | :corporation | :fleet | :threat
  @type plugin_name :: atom()
  @type plugin_module :: module()
  @type registry_state :: %{
          plugins: %{domain() => %{plugin_name() => plugin_module()}},
          plugin_metadata: %{plugin_module() => map()}
        }

  # Public API

  @doc """
  Initialize a new plugin registry.
  """
  @spec initialize() :: {:ok, pid()} | {:error, term()}
  def initialize do
    GenServer.start_link(__MODULE__, %{})
  end

  @doc """
  Register a plugin with the registry.

  ## Examples

      PluginRegistry.register(registry, :character, :combat_stats, MyPlugin)
  """
  @spec register(pid(), domain(), plugin_name(), plugin_module()) :: :ok | {:error, term()}
  def register(registry, domain, plugin_name, plugin_module) do
    GenServer.call(registry, {:register, domain, plugin_name, plugin_module})
  end

  @doc """
  Get a specific plugin module.
  """
  @spec get_plugin(pid(), domain(), plugin_name()) ::
          {:ok, plugin_module()} | {:error, :not_found}
  def get_plugin(registry, domain, plugin_name) do
    GenServer.call(registry, {:get_plugin, domain, plugin_name})
  end

  @doc """
  List all plugins for a domain.
  """
  @spec list_plugins(pid(), domain()) :: [plugin_name()]
  def list_plugins(registry, domain) do
    GenServer.call(registry, {:list_plugins, domain})
  end

  @doc """
  List all available domains.
  """
  @spec list_domains(pid()) :: [domain()]
  def list_domains(registry) do
    GenServer.call(registry, :list_domains)
  end

  @doc """
  Get plugin metadata.
  """
  @spec get_plugin_metadata(pid(), plugin_module()) :: map()
  def get_plugin_metadata(registry, plugin_module) do
    GenServer.call(registry, {:get_metadata, plugin_module})
  end

  @doc """
  Unregister a plugin.
  """
  @spec unregister(pid(), domain(), plugin_name()) :: :ok
  def unregister(registry, domain, plugin_name) do
    GenServer.call(registry, {:unregister, domain, plugin_name})
  end

  @doc """
  Validate that all registered plugins are properly configured.
  """
  @spec validate_plugins(pid()) :: {:ok, map()} | {:error, map()}
  def validate_plugins(registry) do
    GenServer.call(registry, :validate_plugins)
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    state = %{
      plugins: %{
        character: %{},
        corporation: %{},
        fleet: %{},
        threat: %{}
      },
      plugin_metadata: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register, domain, plugin_name, plugin_module}, _from, state) do
    case validate_plugin(plugin_module) do
      :ok ->
        # Register the plugin
        state = put_in(state.plugins[domain][plugin_name], plugin_module)

        # Extract and store metadata
        metadata = extract_plugin_metadata(plugin_module)
        state = put_in(state.plugin_metadata[plugin_module], metadata)

        Logger.debug("Registered plugin",
          domain: domain,
          plugin: plugin_name,
          module: plugin_module
        )

        {:reply, :ok, state}

      {:error, reason} ->
        Logger.warning("Plugin registration failed",
          domain: domain,
          plugin: plugin_name,
          module: plugin_module,
          reason: inspect(reason)
        )

        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_plugin, domain, plugin_name}, _from, state) do
    case get_in(state.plugins, [domain, plugin_name]) do
      nil -> {:reply, {:error, :not_found}, state}
      plugin_module -> {:reply, {:ok, plugin_module}, state}
    end
  end

  @impl true
  def handle_call({:list_plugins, domain}, _from, state) do
    plugins = Map.keys(state.plugins[domain] || %{})
    {:reply, plugins, state}
  end

  @impl true
  def handle_call(:list_domains, _from, state) do
    domains = Map.keys(state.plugins)
    {:reply, domains, state}
  end

  @impl true
  def handle_call({:get_metadata, plugin_module}, _from, state) do
    metadata = Map.get(state.plugin_metadata, plugin_module, %{})
    {:reply, metadata, state}
  end

  @impl true
  def handle_call({:unregister, domain, plugin_name}, _from, state) do
    case get_in(state.plugins, [domain, plugin_name]) do
      nil ->
        {:reply, :ok, state}

      plugin_module ->
        # Remove from plugins registry
        state = update_in(state.plugins[domain], &Map.delete(&1, plugin_name))

        # Remove metadata if no other domain uses this module
        if not module_used_elsewhere?(state.plugins, plugin_module) do
          state = update_in(state.plugin_metadata, &Map.delete(&1, plugin_module))
        end

        Logger.debug("Unregistered plugin",
          domain: domain,
          plugin: plugin_name,
          module: plugin_module
        )

        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_call(:validate_plugins, _from, state) do
    validation_results =
      state.plugin_metadata
      |> Enum.map(fn {plugin_module, metadata} ->
        {plugin_module, validate_plugin_runtime(plugin_module, metadata)}
      end)
      |> Enum.into(%{})

    failed_validations =
      validation_results
      |> Enum.filter(fn {_module, result} -> match?({:error, _}, result) end)
      |> Enum.into(%{})

    if map_size(failed_validations) == 0 do
      {:reply, {:ok, validation_results}, state}
    else
      {:reply, {:error, failed_validations}, state}
    end
  end

  # Private helper functions

  defp validate_plugin(plugin_module) do
    cond do
      not Code.ensure_loaded?(plugin_module) ->
        {:error, :module_not_loaded}

      not function_exported?(plugin_module, :analyze, 3) ->
        {:error, :missing_analyze_function}

      not function_exported?(plugin_module, :plugin_info, 0) ->
        {:error, :missing_plugin_info_function}

      true ->
        # Additional behavior validation
        try do
          info = plugin_module.plugin_info()
          validate_plugin_info(info)
        rescue
          exception ->
            {:error, {:plugin_info_exception, exception}}
        end
    end
  end

  defp validate_plugin_info(info) when is_map(info) do
    required_keys = [:name, :description, :version, :dependencies]

    case Enum.find(required_keys, fn key -> not Map.has_key?(info, key) end) do
      nil -> :ok
      missing_key -> {:error, {:missing_plugin_info_key, missing_key}}
    end
  end

  defp validate_plugin_info(_), do: {:error, :invalid_plugin_info_format}

  defp extract_plugin_metadata(plugin_module) do
    try do
      info = plugin_module.plugin_info()

      Map.merge(info, %{
        module: plugin_module,
        registered_at: DateTime.utc_now(),
        capabilities: extract_capabilities(plugin_module)
      })
    rescue
      _exception ->
        %{
          module: plugin_module,
          registered_at: DateTime.utc_now(),
          error: :failed_to_extract_metadata
        }
    end
  end

  defp extract_capabilities(plugin_module) do
    capabilities = []

    # Check for optional callback implementations
    capabilities =
      if function_exported?(plugin_module, :supports_batch?, 0) do
        [:batch_analysis | capabilities]
      else
        capabilities
      end

    capabilities =
      if function_exported?(plugin_module, :dependencies, 0) do
        [:has_dependencies | capabilities]
      else
        capabilities
      end

    capabilities =
      if function_exported?(plugin_module, :cache_strategy, 0) do
        [:custom_caching | capabilities]
      else
        capabilities
      end

    capabilities
  end

  defp validate_plugin_runtime(plugin_module, metadata) do
    try do
      # Basic runtime validation - ensure plugin can be called
      # This is a lightweight validation, not a full analysis

      case plugin_module.plugin_info() do
        info when is_map(info) ->
          # Check dependencies are available
          case Map.get(info, :dependencies, []) do
            [] -> :ok
            dependencies -> validate_dependencies(dependencies)
          end

        _ ->
          {:error, :invalid_plugin_info_response}
      end
    rescue
      exception ->
        {:error, {:runtime_validation_failed, exception}}
    end
  end

  defp validate_dependencies(dependencies) when is_list(dependencies) do
    case Enum.find(dependencies, fn dep -> not dependency_available?(dep) end) do
      nil -> :ok
      missing_dep -> {:error, {:missing_dependency, missing_dep}}
    end
  end

  defp dependency_available?(dependency) when is_atom(dependency) do
    # Check if module exists
    Code.ensure_loaded?(dependency)
  end

  defp dependency_available?({:module, module}) when is_atom(module) do
    Code.ensure_loaded?(module)
  end

  defp dependency_available?({:application, app}) when is_atom(app) do
    case Application.spec(app) do
      nil -> false
      _app_info -> true
    end
  end

  defp dependency_available?(_), do: false

  defp module_used_elsewhere?(plugins, target_module) do
    plugins
    |> Enum.flat_map(fn {_domain, domain_plugins} ->
      Map.values(domain_plugins)
    end)
    |> Enum.any?(fn module -> module == target_module end)
  end
end
