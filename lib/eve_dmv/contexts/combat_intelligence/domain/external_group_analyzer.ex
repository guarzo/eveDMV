defmodule EveDmv.Contexts.CombatIntelligence.Domain.ExternalGroupAnalyzer do
  @moduledoc """
  Analyzes external groups (corporations/alliances) that a character has collaborated with.
  """

  @doc """
  Analyze external groups for a character within a given time range.
  """
  @spec analyze(integer(), DateTime.t()) :: {:ok, list(map())} | {:error, term()}
  def analyze(character_id, since_date) do
    # Delegate to PlayerRepository which contains the consolidated external groups logic.
    # QueryCache.get_or_compute already wraps results in {:ok, value}
    EveDmv.Contexts.PlayerProfile.Infrastructure.PlayerRepository.get_external_groups(
      character_id,
      since_date
    )
  end
end
