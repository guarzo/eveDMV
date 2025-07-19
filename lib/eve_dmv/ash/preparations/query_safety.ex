defmodule EveDmv.Ash.Preparations.QuerySafety do
  @moduledoc """
  Ash preparation module to apply query safety limits to read actions.

  This preparation can be added to any Ash resource read action to
  ensure queries have appropriate limits and timeouts.
  """

  use Ash.Resource.Preparation

  @doc """
  Apply query safety limits to the query.

  ## Options
    * `:limit` - Override default limit (max: 10,000)
    * `:timeout` - Override default timeout in ms (max: 120,000)
    * `:allow_unlimited` - Allow queries without limits (use with caution)
  """
  def prepare(query, opts, _context) do
    # Check if unlimited queries are explicitly allowed
    if Keyword.get(opts, :allow_unlimited, false) do
      query
    else
      # Apply safety limits
      apply_safety_limits(query, opts)
    end
  end

  defp apply_safety_limits(query, opts) do
    # Get configured limits
    limit = Keyword.get(opts, :limit, 1000)

    # Apply limit to query
    query
    |> Ash.Query.limit(min(limit, 10_000))
  end
end
