defmodule EveDmv.CacheSupervisor do
  @moduledoc """
  Compatibility module that delegates to the reorganized cache supervisor.
  This module exists to maintain backward compatibility after Phase 5 reorganization.
  """

  defdelegate start_link(opts), to: EveDmv.Platform.Cache.CacheSupervisor
  defdelegate cache_name(namespace), to: EveDmv.Platform.Cache.CacheSupervisor
  defdelegate init(args), to: EveDmv.Platform.Cache.CacheSupervisor
  defdelegate all_cache_stats(), to: EveDmv.Platform.Cache.CacheSupervisor
  defdelegate clear_all_caches(), to: EveDmv.Platform.Cache.CacheSupervisor
end
