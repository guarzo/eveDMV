defmodule IntelligenceEngine do
  @moduledoc """
  Main intelligence engine for analyzing EVE Online entities.

  This module provides the primary interface for running various intelligence
  analyses on characters, corporations, and other game entities.
  """

  alias EveDmv.Intelligence.Core.IntelligenceCoordinator

  @doc """
  Analyze an entity with specified scope.

  ## Parameters
  - entity_type: :character, :corporation, :alliance, etc.
  - entity_id: The ID of the entity to analyze
  - opts: Analysis options including :scope

  ## Examples

      IntelligenceEngine.analyze(:character, 12345, scope: :basic)
      IntelligenceEngine.analyze(:character, 12345, scope: :standard)
  """
  @spec analyze(atom(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  def analyze(entity_type, entity_id, opts \\ []) do
    scope = Keyword.get(opts, :scope, :basic)

    case {entity_type, scope} do
      {:character, :basic} ->
        IntelligenceCoordinator.analyze_character_basic(entity_id)

      {:character, :standard} ->
        # For standard analysis, use basic for now
        # In future would do more comprehensive analysis
        IntelligenceCoordinator.analyze_character_basic(entity_id)

      _ ->
        {:error, :unsupported_analysis_type}
    end
  end
end
