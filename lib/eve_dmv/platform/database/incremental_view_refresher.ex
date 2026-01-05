defmodule EveDmv.Platform.Database.IncrementalViewRefresher do
  @moduledoc """
  DEPRECATED: Use `EveDmv.Platform.Database.MaterializedViewRefresher` instead.

  This module has been renamed to better reflect its functionality. PostgreSQL
  materialized views only support full refresh; there is no incremental option.

  This forwarding module is provided for backward compatibility and will be
  removed in a future release.
  """

  @deprecated "Use EveDmv.Platform.Database.MaterializedViewRefresher instead"
  defdelegate start_link(opts), to: EveDmv.Platform.Database.MaterializedViewRefresher

  @deprecated "Use EveDmv.Platform.Database.MaterializedViewRefresher.refresh_view/2 instead"
  defdelegate refresh_view(view_name, opts \\ []),
    to: EveDmv.Platform.Database.MaterializedViewRefresher

  @deprecated "Use EveDmv.Platform.Database.MaterializedViewRefresher.get_refresh_status/0 instead"
  defdelegate get_refresh_status(), to: EveDmv.Platform.Database.MaterializedViewRefresher

  @deprecated "Use EveDmv.Platform.Database.MaterializedViewRefresher.force_full_refresh/1 instead"
  defdelegate force_full_refresh(view_name),
    to: EveDmv.Platform.Database.MaterializedViewRefresher
end
