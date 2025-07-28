defmodule MatchingEngine do
  @moduledoc "Temporary stub for matching engine operations - TODO: implement"

  alias EveDmv.Contexts.Surveillance.Domain.MatchingEngine, as: RealEngine

  defdelegate test_criteria(criteria, test_data), to: RealEngine
end
