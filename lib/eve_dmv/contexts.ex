defmodule EveDmv.Contexts do
  @moduledoc """
  Defines the bounded contexts and their relationships in the EVE DMV system.

  This module serves as the context map, documenting how different bounded
  contexts relate to each other and what events they publish/subscribe to.
  """

  @contexts %{
    killmail_processing: %{
      name: "Killmail Processing",
      description: "Real-time ingestion and enrichment of EVE Online killmail data",
      type: :core,
      module_prefix: EveDmv.Contexts.KillmailProcessing,
      publishes: [:killmail_received, :killmail_enriched, :killmail_failed],
      subscribes: [],
      dependencies: [:eve_universe, :market_intelligence]
    },
    combat_intelligence: %{
      name: "Combat Intelligence",
      description:
        "Tactical analysis and intelligence generation for characters and corporations",
      type: :core,
      module_prefix: EveDmv.Contexts.CombatIntelligence,
      publishes: [:character_analyzed, :corporation_analyzed, :threat_detected],
      subscribes: [:killmail_enriched],
      dependencies: [:eve_universe]
    },
    fleet_operations: %{
      name: "Fleet Operations",
      description: "Fleet composition analysis and effectiveness metrics",
      type: :core,
      module_prefix: EveDmv.Contexts.FleetOperations,
      publishes: [:fleet_analyzed, :doctrine_validated],
      subscribes: [:killmail_enriched],
      dependencies: [:eve_universe]
    },
    wormhole_operations: %{
      name: "Wormhole Operations",
      description: "Wormhole-specific tactics, chain management, and vetting",
      type: :core,
      module_prefix: EveDmv.Contexts.WormholeOperations,
      publishes: [:chain_updated, :vetting_completed, :mass_calculated],
      subscribes: [:killmail_enriched, :character_analyzed],
      dependencies: [:eve_universe, :combat_intelligence]
    },
    surveillance: %{
      name: "Surveillance",
      description: "Real-time threat monitoring and alerting",
      type: :core,
      module_prefix: EveDmv.Contexts.Surveillance,
      publishes: [:match_found, :alert_triggered],
      subscribes: [:killmail_received],
      dependencies: []
    },
    market_intelligence: %{
      name: "Market Intelligence",
      description: "Item valuation and market analysis",
      type: :supporting,
      module_prefix: EveDmv.Contexts.MarketIntelligence,
      publishes: [:price_updated, :market_analyzed],
      subscribes: [],
      dependencies: [:eve_universe]
    },
    eve_universe: %{
      name: "EVE Universe",
      description: "EVE Online game data integration and static data",
      type: :supporting,
      module_prefix: EveDmv.Contexts.EveUniverse,
      publishes: [:static_data_updated],
      subscribes: [],
      dependencies: []
    }
  }

  @type context_name :: atom()
  @type context_type :: :core | :supporting | :generic
  @type event_name :: atom()

  @type context :: %{
          name: String.t(),
          description: String.t(),
          type: context_type(),
          module_prefix: module(),
          publishes: [event_name()],
          subscribes: [event_name()],
          dependencies: [context_name()]
        }

  @doc """
  Get all defined contexts.
  """
  @spec all() :: %{context_name() => context()}
  def all, do: @contexts

  @doc """
  Get a specific context by name.
  """
  @spec get(context_name()) :: {:ok, context()} | {:error, :not_found}
  def get(context_name) do
    case Map.get(@contexts, context_name) do
      nil -> {:error, :not_found}
      context -> {:ok, context}
    end
  end

  @doc """
  Get all core contexts.
  """
  @spec core_contexts() :: %{context_name() => context()}
  def core_contexts do
    @contexts
    |> Enum.filter(fn {_, context} -> context.type == :core end)
    |> Map.new()
  end

  @doc """
  Get all contexts that publish a specific event.
  """
  @spec publishers_of(event_name()) :: [context_name()]
  def publishers_of(event_name) do
    @contexts
    |> Enum.filter(fn {_, context} -> event_name in context.publishes end)
    |> Enum.map(fn {name, _} -> name end)
  end

  @doc """
  Get all contexts that subscribe to a specific event.
  """
  @spec subscribers_of(event_name()) :: [context_name()]
  def subscribers_of(event_name) do
    @contexts
    |> Enum.filter(fn {_, context} -> event_name in context.subscribes end)
    |> Enum.map(fn {name, _} -> name end)
  end

  @doc """
  Validate that all subscribed events have publishers.
  """
  @spec validate_event_flow() :: :ok | {:error, [{context_name(), event_name()}]}
  def validate_event_flow do
    errors =
      Enum.flat_map(@contexts, fn {context_name, context} ->
        context.subscribes
        |> Enum.filter(fn event -> publishers_of(event) == [] end)
        |> Enum.map(fn event -> {context_name, event} end)
      end)

    case errors do
      [] -> :ok
      errors -> {:error, errors}
    end
  end

  @doc """
  Get the dependency graph for visualization.
  Returns a list of edges in the format {from_context, to_context, relationship_type}.
  """
  @spec dependency_graph() :: [{context_name(), context_name(), :depends_on | :publishes_to}]
  def dependency_graph do
    direct_dependencies =
      Enum.flat_map(@contexts, fn {context_name, context} ->
        Enum.map(context.dependencies, fn dep ->
          {context_name, dep, :depends_on}
        end)
      end)

    event_dependencies =
      Enum.flat_map(@contexts, fn {context_name, context} ->
        Enum.flat_map(context.subscribes, fn event ->
          Enum.map(publishers_of(event), fn publisher ->
            {context_name, publisher, :publishes_to}
          end)
        end)
      end)

    direct_dependencies ++ event_dependencies
  end

  @doc """
  Check if a context has any circular dependencies.
  """
  @spec has_circular_dependencies?(context_name()) :: boolean()
  def has_circular_dependencies?(context_name) do
    check_circular_deps(context_name, context_name, MapSet.new())
  end

  defp check_circular_deps(current, target, visited) do
    if MapSet.member?(visited, current) do
      current == target
    else
      visited = MapSet.put(visited, current)

      case get(current) do
        {:ok, context} ->
          deps = context.dependencies ++ get_event_dependencies(current)
          Enum.any?(deps, fn dep -> check_circular_deps(dep, target, visited) end)

        {:error, _} ->
          false
      end
    end
  end

  defp get_event_dependencies(context_name) do
    case get(context_name) do
      {:ok, context} ->
        context.subscribes
        |> Enum.flat_map(&publishers_of/1)
        |> Enum.uniq()

      {:error, _} ->
        []
    end
  end
end
