defmodule EveDmv.Ash.Preparations.ApplyQuerySafety do
  @moduledoc """
  Module to apply query safety preparations to Ash resources.

  This module provides macros and functions to easily add query safety
  to existing Ash resources without modifying each resource file individually.
  """

  defmacro __using__(_opts) do
    quote do
      # Override the read macro to automatically add query safety
      defmacro read(name, do: block) do
        quote do
          read unquote(name) do
            # Add query safety preparation
            prepare(EveDmv.Ash.Preparations.QuerySafety)

            # Execute the original block
            unquote(block)
          end
        end
      end
    end
  end

  @doc """
  Apply query safety to all read actions in a resource.

  This can be called in a resource's `preparations` block:

      preparations do
        prepare EveDmv.Ash.Preparations.ApplyQuerySafety.default_safety(), for: :read
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
  def for_actions(action_names, opts \\ []) do
    limit = Keyword.get(opts, :limit, 1000)

    fn query, _context ->
      if query.action.name in action_names do
        EveDmv.Ash.Preparations.QuerySafety.prepare(query, [limit: limit], %{})
      else
        query
      end
    end
  end
end
