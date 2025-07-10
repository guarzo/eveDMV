defmodule EveDmv.Repo.Migrations.AddJune2025Partition do
  use Ecto.Migration

  def change do
    # Create June 2025 partition for killmails_raw
    # Proactively creating partitions several months in advance ensures
    # continuous operation without manual intervention
    execute """
    CREATE TABLE IF NOT EXISTS killmails_raw_2025_06 PARTITION OF killmails_raw
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01')
    """

    # Create June 2025 partition for killmails_enriched
    # Maintains partition parity between raw and enriched tables
    # This allows efficient JOIN operations across partitioned data
    execute """
    CREATE TABLE IF NOT EXISTS killmails_enriched_2025_06 PARTITION OF killmails_enriched
    FOR VALUES FROM ('2025-06-01') TO ('2025-07-01')
    """
  end
end