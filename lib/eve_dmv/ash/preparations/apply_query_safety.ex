defmodule EveDmv.Ash.Preparations.ApplyQuerySafety do
  @moduledoc """
  Module to apply query safety preparations to Ash resources.

  This module provides functions to easily add query safety
  to existing Ash resources without modifying each resource file individually.

  Usage in resource preparations block:

      preparations do
        EveDmv.Ash.Preparations.ApplyQuerySafety.default_safety(prepare), for: :read
      end
  """

  @doc """
  Apply query safety to all read actions in a resource.

  This can be called in a resource's `preparations` block:

      preparations do
        EveDmv.Ash.Preparations.ApplyQuerySafety.default_safety(prepare), for: :read
      end
  """
  def default_safety do
    {EveDmv.Ash.Preparations.QuerySafety, [limit: 1000]}
  end

  @doc """
  Apply query safety with custom limits.

  Example:
      preparations do
        prepare EveDmv.Ash.Preparations.ApplyQuerySafety.with_limit(5000), for: :read
      end
  """
  def with_limit(limit) do
    {EveDmv.Ash.Preparations.QuerySafety, [limit: limit]}
  end

  @doc """
  Apply query safety to specific actions only.

  Example:
      preparations do
        prepare EveDmv.Ash.Preparations.ApplyQuerySafety.for_actions([:list, :search]), for: :read
      end
  """
  def for_actions(action_names, opts \\ []) when is_list(action_names) do
    unless Enum.all?(action_names, &is_atom/1) do
      raise ArgumentError, "action_names must be a list of atoms"
    end

    limit = Keyword.get(opts, :limit, 1000)

    {EveDmv.Ash.Preparations.QuerySafety, [limit: limit, only_actions: action_names]}
  end
end
