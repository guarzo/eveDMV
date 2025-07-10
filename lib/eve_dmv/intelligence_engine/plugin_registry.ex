defmodule EveDmv.IntelligenceEngine.PluginRegistry do
  @moduledoc """
  Legacy plugin registry compatibility layer.

  In the new bounded context system, "plugins" are now domain-specific
  analyzers. This module provides backward compatibility for the old
  plugin registry API.
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def register(registry, domain, plugin_name, module) do
    GenServer.call(registry, {:register, domain, plugin_name, module})
  end

  def get_plugin(registry, domain, plugin_name) do
    GenServer.call(registry, {:get_plugin, domain, plugin_name})
  end

  def list_plugins(registry, domain) do
    GenServer.call(registry, {:list_plugins, domain})
  end

  def unregister(registry, domain, plugin_name) do
    GenServer.call(registry, {:unregister, domain, plugin_name})
  end

  # Server Implementation

  @impl GenServer
  def init(_opts) do
    # Initialize with default "plugins" that map to bounded contexts
    default_plugins = %{
      character: %{
        combat_stats: EveDmv.Contexts.PlayerProfile.Analyzers.CombatStatsAnalyzer,
        behavioral_patterns: EveDmv.Contexts.PlayerProfile.Analyzers.BehavioralPatternsAnalyzer,
        ship_preferences: EveDmv.Contexts.PlayerProfile.Analyzers.ShipPreferencesAnalyzer,
        threat_assessment: EveDmv.Contexts.ThreatAssessment.Analyzers.ThreatAnalyzer
      },
      corporation: %{
        member_activity: EveDmv.Contexts.CorporationAnalysis.Analyzers.MemberActivityAnalyzer,
        participation: EveDmv.Contexts.CorporationAnalysis.Analyzers.ParticipationAnalyzer
      },
      fleet: %{
        composition: EveDmv.Contexts.FleetOperations.Domain.FleetAnalyzer,
        effectiveness: EveDmv.Contexts.FleetOperations.Domain.EffectivenessCalculator
      }
    }

    {:ok, default_plugins}
  end

  @impl GenServer
  def handle_call({:register, domain, plugin_name, module}, _from, state) do
    domain_plugins = Map.get(state, domain, %{})
    updated_domain = Map.put(domain_plugins, plugin_name, module)
    new_state = Map.put(state, domain, updated_domain)

    Logger.debug("Registered plugin #{plugin_name} for domain #{domain}")
    {:reply, :ok, new_state}
  end

  @impl GenServer
  def handle_call({:get_plugin, domain, plugin_name}, _from, state) do
    case get_in(state, [domain, plugin_name]) do
      nil -> {:reply, {:error, :plugin_not_found}, state}
      module -> {:reply, {:ok, module}, state}
    end
  end

  @impl GenServer
  def handle_call({:list_plugins, domain}, _from, state) do
    plugins =
      case Map.get(state, domain) do
        nil ->
          []

        domain_plugins ->
          Enum.map(domain_plugins, fn {name, module} -> {name, module} end)
      end

    {:reply, plugins, state}
  end

  @impl GenServer
  def handle_call({:unregister, domain, plugin_name}, _from, state) do
    case get_in(state, [domain, plugin_name]) do
      nil ->
        {:reply, {:error, :plugin_not_found}, state}

      _module ->
        domain_plugins = Map.get(state, domain, %{})
        updated_domain = Map.delete(domain_plugins, plugin_name)
        new_state = Map.put(state, domain, updated_domain)

        Logger.debug("Unregistered plugin #{plugin_name} from domain #{domain}")
        {:reply, :ok, new_state}
    end
  end
end
