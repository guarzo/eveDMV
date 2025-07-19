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
  def safety_config_for(resource) do
    resource_name = Module.split(resource) |> List.last()

    case resource_name do
      # High-volume resources need stricter limits
      "KillmailRaw" -> [limit: 500]
      "Participant" -> [limit: 1000]
      "CharacterStats" -> [limit: 1000]
      # Profile and surveillance resources
      "Profile" -> [limit: 100]
      "ProfileMatch" -> [limit: 500]
      "Notification" -> [limit: 200]
      # Analytics resources
      "PlayerStats" -> [limit: 1000]
      "ShipStats" -> [limit: 1000]
      # Battle analysis resources
      "Battle" -> [limit: 100]
      "BattleKillmail" -> [limit: 500]
      "CombatLog" -> [limit: 1000]
      # System resources
      "SolarSystem" -> [limit: 5000, allow_unlimited: true]
      "ItemType" -> [limit: 5000, allow_unlimited: true]
      # Default for other resources
      _ -> [limit: 1000]
    end
  end

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
    resource = query.resource
    action_name = query.action.name

    if action_name in unsafe_actions() do
      query
    else
      case safety_config_for(resource) do
        nil -> query
        config -> EveDmv.Ash.Preparations.QuerySafety.prepare(query, config, %{})
      end
    end
  end
end
