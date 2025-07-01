defmodule EveDmv.Repo.Migrations.CreateKillmailsRawJuly2025Partition do
  use Ecto.Migration

  def change do
    # Create July 2025 partition for killmails_raw
    execute """
    CREATE TABLE IF NOT EXISTS killmails_raw_2025_07 PARTITION OF killmails_raw
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01')
    """
    
    # Create July 2025 partition for killmails_enriched
    execute """
    CREATE TABLE IF NOT EXISTS killmails_enriched_2025_07 PARTITION OF killmails_enriched
    FOR VALUES FROM ('2025-07-01') TO ('2025-08-01')
    """
  end
end
