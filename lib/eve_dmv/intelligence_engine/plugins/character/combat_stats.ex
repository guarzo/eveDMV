defmodule EveDmv.IntelligenceEngine.Plugins.Character.CombatStats do
  @moduledoc """
  Combat statistics plugin for character analysis.

  This is a compatibility layer that bridges the old plugin system
  to the new bounded context analyzers.
  """

  @behaviour EveDmv.IntelligenceEngine.Plugin

  alias EveDmv.Contexts.PlayerProfile.Analyzers.CombatStatsAnalyzer

  @doc """
  Plugin metadata and information.
  """
  @impl EveDmv.IntelligenceEngine.Plugin
  def plugin_info do
    %{
      name: "Combat Statistics",
      description: "Analyzes character combat performance and statistics",
      version: "2.0.0",
      author: "EVE DMV Team",
      tags: [:combat, :statistics, :character],
      dependencies: [EveDmv.Database.CharacterRepository, EveDmv.Database.KillmailRepository]
    }
  end

  @doc """
  Analyze combat statistics for a character.

  Delegates to the bounded context analyzer.
  """
  @impl EveDmv.IntelligenceEngine.Plugin
  def analyze(entity_id, base_data, _opts \\ []) do
    # Delegate to the bounded context analyzer with the correct arguments
    case CombatStatsAnalyzer.analyze(entity_id, base_data) do
      {:ok, result} ->
        {:ok,
         Map.merge(base_data, %{
           combat_stats: result,
           plugin_version: "2.0.0",
           analyzed_at: DateTime.utc_now()
         })}

      {:error, %EveDmv.Core.Errors.Error{} = error} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Whether this plugin supports batch analysis.
  """
  @impl EveDmv.IntelligenceEngine.Plugin
  def supports_batch? do
    true
  end

  @doc """
  Plugin dependencies.
  """
  @impl EveDmv.IntelligenceEngine.Plugin
  def dependencies do
    [EveDmv.Database.CharacterRepository, EveDmv.Database.KillmailRepository]
  end

  @doc """
  Cache strategy for this plugin.
  """
  @impl EveDmv.IntelligenceEngine.Plugin
  def cache_strategy do
    %{
      strategy: :ttl,
      ttl_seconds: 300,
      invalidate_on: [:killmail_update, :character_update]
    }
  end
end
