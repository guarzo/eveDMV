defmodule EveDmv.Repo.Migrations.AdvancedFeatures do
  @moduledoc """
  Minimal advanced database features that work with current schema:
  - Table partitioning for killmails_raw
  - Simple materialized views for analytics
  - Helper functions
  """
  
  use Ecto.Migration
  
  def up do
    # =====================================
    # Table Partitioning for Killmails
    # =====================================
    
    # Create partitioned version of killmails_raw
    execute """
    CREATE TABLE IF NOT EXISTS killmails_raw_partitioned (
      LIKE killmails_raw INCLUDING ALL EXCLUDING INDEXES
    ) PARTITION BY RANGE (killmail_time);
    """
    
    # Create monthly partitions for the last 6 months and next month
    create_monthly_partitions()
    
    # =====================================
    # Materialized Views for Analytics
    # =====================================
    
    # Character activity summary (without monetary values)
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS character_activity_summary AS
    SELECT 
      p.character_id,
      p.character_name,
      COUNT(*) FILTER (WHERE p.is_victim = false) as total_kills,
      COUNT(*) FILTER (WHERE p.is_victim = true) as total_losses,
      MAX(k.killmail_time) as last_activity,
      COUNT(DISTINCT k.solar_system_id) as unique_systems,
      COUNT(DISTINCT p.ship_type_id) as unique_ships_flown
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    GROUP BY p.character_id, p.character_name
    """
    
    # Create indexes for character activity summary
    execute "CREATE UNIQUE INDEX ON character_activity_summary (character_id)"
    execute "CREATE INDEX ON character_activity_summary (total_kills DESC)"
    execute "CREATE INDEX ON character_activity_summary (last_activity DESC)"
    
    # System activity heatmap (simplified)
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS system_activity_heatmap AS
    SELECT 
      solar_system_id,
      DATE_TRUNC('hour', killmail_time) as hour,
      COUNT(*) as kill_count,
      COUNT(DISTINCT victim_character_id) as unique_victims,
      COUNT(DISTINCT victim_corporation_id) as unique_corporations,
      AVG(attacker_count) as avg_attacker_count
    FROM killmails_raw
    WHERE killmail_time >= CURRENT_TIMESTAMP - INTERVAL '7 days'
    GROUP BY solar_system_id, DATE_TRUNC('hour', killmail_time)
    """
    
    # Create indexes for system activity heatmap
    execute "CREATE INDEX ON system_activity_heatmap (solar_system_id, hour DESC)"
    execute "CREATE INDEX ON system_activity_heatmap (kill_count DESC)"
    
    # Ship type usage
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS ship_type_usage AS
    SELECT 
      p.ship_type_id,
      it.type_name as ship_name,
      COUNT(*) FILTER (WHERE p.is_victim = false) as kills_with,
      COUNT(*) FILTER (WHERE p.is_victim = true) as losses_with,
      COUNT(DISTINCT p.character_id) as unique_pilots,
      CASE 
        WHEN COUNT(*) FILTER (WHERE p.is_victim = true) = 0 THEN 100.0
        ELSE ROUND(
          COUNT(*) FILTER (WHERE p.is_victim = false)::numeric * 100.0 / 
          COUNT(*)::numeric, 2
        )
      END as effectiveness_ratio
    FROM participants p
    LEFT JOIN eve_item_types it ON p.ship_type_id = it.type_id
    GROUP BY p.ship_type_id, it.type_name
    HAVING COUNT(*) > 10
    """
    
    # Create indexes for ship type usage
    execute "CREATE UNIQUE INDEX ON ship_type_usage (ship_type_id)"
    execute "CREATE INDEX ON ship_type_usage (effectiveness_ratio DESC)"
    
    # =====================================
    # Tracking Table for View Refreshes
    # =====================================
    
    execute """
    CREATE TABLE IF NOT EXISTS view_refresh_tracking (
      view_name TEXT PRIMARY KEY,
      last_refresh_time TIMESTAMP WITH TIME ZONE,
      last_full_refresh_time TIMESTAMP WITH TIME ZONE,
      refresh_duration_ms INTEGER,
      rows_updated INTEGER,
      refresh_type TEXT
    )
    """
    
    # =====================================
    # Helper Functions
    # =====================================
    
    # Function to classify engagement type
    execute """
    CREATE OR REPLACE FUNCTION classify_engagement(attacker_count INTEGER) 
    RETURNS TEXT AS $$
    BEGIN
      RETURN CASE
        WHEN attacker_count = 1 THEN 'solo'
        WHEN attacker_count <= 5 THEN 'small_gang'
        WHEN attacker_count <= 15 THEN 'medium_gang'
        WHEN attacker_count <= 50 THEN 'large_gang'
        ELSE 'fleet_battle'
      END;
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """
  end
  
  def down do
    # Drop functions
    execute "DROP FUNCTION IF EXISTS classify_engagement(INTEGER);"
    
    # Drop tracking table
    execute "DROP TABLE IF EXISTS view_refresh_tracking;"
    
    # Drop materialized views
    execute "DROP MATERIALIZED VIEW IF EXISTS ship_type_usage;"
    execute "DROP MATERIALIZED VIEW IF EXISTS system_activity_heatmap;"
    execute "DROP MATERIALIZED VIEW IF EXISTS character_activity_summary;"
    
    # Drop partitioned table (this will also drop all partitions)
    execute "DROP TABLE IF EXISTS killmails_raw_partitioned CASCADE;"
  end
  
  # Helper to create monthly partitions
  defp create_monthly_partitions do
    # Create partitions for the last 6 months and next month
    -6..1
    |> Enum.each(fn month_offset ->
      date = Date.utc_today() |> Date.add(month_offset * 30)
      year = date.year
      month = date.month |> Integer.to_string() |> String.pad_leading(2, "0")
      
      partition_name = "killmails_raw_y#{year}m#{month}"
      start_date = "#{year}-#{month}-01"
      
      # Calculate end date (first day of next month)
      {end_year, end_month} = 
        if date.month == 12 do
          {year + 1, 1}
        else
          {year, date.month + 1}
        end
      
      end_month_str = end_month |> Integer.to_string() |> String.pad_leading(2, "0")
      end_date = "#{end_year}-#{end_month_str}-01"
      
      execute """
      CREATE TABLE IF NOT EXISTS #{partition_name} 
      PARTITION OF killmails_raw_partitioned 
      FOR VALUES FROM ('#{start_date}') TO ('#{end_date}');
      """
      
      # Create indexes on the partition
      execute """
      CREATE INDEX IF NOT EXISTS #{partition_name}_system_time_idx 
      ON #{partition_name} (solar_system_id, killmail_time);
      """
      
      execute """
      CREATE INDEX IF NOT EXISTS #{partition_name}_victim_time_idx 
      ON #{partition_name} (victim_character_id, killmail_time);
      """
    end)
  end
end