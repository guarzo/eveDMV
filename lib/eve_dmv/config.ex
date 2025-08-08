defmodule EveDmv.Config do
  @moduledoc """
  Compatibility module that delegates to the reorganized config module.
  This module exists to maintain backward compatibility after Phase 5 reorganization.
  """

  defdelegate get(app, key, default \\ nil), to: EveDmv.Core.Config.Config
end
