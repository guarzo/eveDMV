defmodule EveDmv.Repo.Migrations.AddUniqueIndexToSystemActivityHeatmap do
  @moduledoc """
  Adds a unique index to system_activity_heatmap materialized view.

  This is required for REFRESH MATERIALIZED VIEW CONCURRENTLY to work.
  PostgreSQL requires a unique index with no WHERE clause on one or more
  columns of the materialized view for concurrent refresh.
  """

  use Ecto.Migration

  def up do
    # Add unique index on the GROUP BY columns (solar_system_id, hour)
    # This enables REFRESH MATERIALIZED VIEW CONCURRENTLY to work
    execute """
    CREATE UNIQUE INDEX IF NOT EXISTS system_activity_heatmap_unique_idx
    ON system_activity_heatmap (solar_system_id, hour)
    """
  end

  def down do
    execute """
    DROP INDEX IF EXISTS system_activity_heatmap_unique_idx
    """
  end
end
