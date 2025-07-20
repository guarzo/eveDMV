defmodule EveDmv.Ash.QuerySafetyConfig do
  @moduledoc """
  Configuration for query safety limits across Ash resources.

  This module provides a centralized way to configure query safety
  for all resources without modifying each resource file.
  """

  @doc """
  Get query safety configuration for a specific resource.

  Returns a keyword list with safety options or nil if no safety should be applied.
  """
  # High-volume resources need stricter limits
  def safety_config_for(EveDmv.Killmails.KillmailRaw), do: [limit: 500]
  def safety_config_for(EveDmv.Killmails.Participant), do: [limit: 1000]
  def safety_config_for(EveDmv.Intelligence.CharacterStats), do: [limit: 1000]

  # Profile and surveillance resources
  def safety_config_for(EveDmv.Surveillance.Profile), do: [limit: 100]
  def safety_config_for(EveDmv.Surveillance.ProfileMatch), do: [limit: 500]
  def safety_config_for(EveDmv.Surveillance.Notification), do: [limit: 200]

  # Analytics resources
  def safety_config_for(EveDmv.Analytics.PlayerStats), do: [limit: 1000]
  def safety_config_for(EveDmv.Analytics.ShipStats), do: [limit: 1000]

  # Battle analysis resources
  def safety_config_for(EveDmv.BattleAnalysis.Battle), do: [limit: 100]
  def safety_config_for(EveDmv.BattleAnalysis.BattleKillmail), do: [limit: 500]
  def safety_config_for(EveDmv.BattleAnalysis.CombatLog), do: [limit: 1000]

  # System resources
  def safety_config_for(EveDmv.Eve.SolarSystem), do: [limit: 5000, allow_unlimited: true]
  def safety_config_for(EveDmv.Eve.ItemType), do: [limit: 5000, allow_unlimited: true]

  # Default for other resources
  def safety_config_for(_), do: [limit: 1000]

  @doc """
  Actions that should bypass query safety.

  Some internal actions need to fetch all records.
  """
  def unsafe_actions do
    [:export_all, :admin_query, :internal_sync]
  end

  @doc """
  Apply query safety to a query based on resource configuration.
  """
  def apply_safety(query) do
    # Verify query structure before accessing fields
    with %{resource: resource} <- query,
         %{action: %{name: action_name}} <- query do
      if action_name in unsafe_actions() do
        query
      else
        case safety_config_for(resource) do
          nil -> query
          config -> EveDmv.Ash.Preparations.QuerySafety.prepare(query, config, %{})
        end
      end
    else
      # If query doesn't have expected structure, return unchanged
      _ -> query
    end
  end
end
