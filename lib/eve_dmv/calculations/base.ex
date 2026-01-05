defmodule EveDmv.Calculations.Base do
  @moduledoc """
  Base module for shared calculation patterns.
  Use this as a starting point for Ash calculations.

  ## Usage

      defmodule MyCalculation do
        use EveDmv.Calculations.Base

        # You now have access to:
        # - Ash.Resource.Calculation behaviour
        # - EveDmv.Calculations.Helpers functions
      end
  """

  defmacro __using__(_opts) do
    quote do
      use Ash.Resource.Calculation
      import EveDmv.Calculations.Helpers
    end
  end
end
