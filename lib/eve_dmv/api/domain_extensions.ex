defmodule EveDmv.Api.DomainExtensions do
  @moduledoc """
  Domain-level extensions and configurations for the EVE DMV API.

  This module provides hooks and extensions that apply to all resources
  in the domain, including query safety preparations.
  """

  @doc """
  Create a preparation function that applies query safety.

  This can be used in individual resources or applied globally.
  """
  def query_safety_preparation do
    fn query, _context ->
      EveDmv.Ash.QuerySafetyConfig.apply_safety(query)
    end
  end

  defmodule QuerySafety do
    @moduledoc """
    Macro to add query safety to a resource's preparations block.

    Usage in a resource:
        use EveDmv.Api.DomainExtensions.QuerySafety
    """
    defmacro __using__(opts) do
      quote do
        preparations do
          prepare(fn query, _context ->
            opts =
              unquote(Macro.escape(Keyword.take(opts, [:limit, :allow_unlimited])))

            # Use provided options or fall back to default config
            if opts == [] do
              EveDmv.Ash.QuerySafetyConfig.apply_safety(query)
            else
              EveDmv.Ash.Preparations.QuerySafety.prepare(query, opts, %{})
            end
          end)
        end
      end
    end
  end
end
