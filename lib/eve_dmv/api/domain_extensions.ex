defmodule EveDmv.Api.DomainExtensions do
  @moduledoc """
  Domain-level extensions and configurations for the EVE DMV API.

  This module provides hooks and extensions that apply to all resources
  in the domain, including query safety preparations.
  """

  @doc """
  Apply default preparations to all read actions in the domain.

  This function should be called during API compilation to ensure
  all read queries have appropriate safety limits.
  """
  def apply_query_safety_to_domain(_domain_module) do
    # This would need to be implemented as a compile-time hook
    # For now, we'll document the manual process
    :ok
  end

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
    defmacro __using__(_opts) do
      quote do
        preparations do
          prepare(EveDmv.Api.DomainExtensions.query_safety_preparation())
        end
      end
    end
  end
end
