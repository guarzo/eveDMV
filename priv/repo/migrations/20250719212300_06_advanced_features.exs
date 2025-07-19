defmodule EveDmv.Repo.Migrations.AdvancedFeatures do
  @moduledoc """
  Advanced database features including:
  - Table partitioning for killmails_raw
  - Materialized views for analytics
  - Triggers for automatic updates
  - Custom functions for complex calculations
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
    """, ""
    
    # Create monthly partitions for the last 6 months and next month
    create_monthly_partitions()
    
    # Create trigger to automatically create new partitions
    execute """
    CREATE OR REPLACE FUNCTION create_monthly_partition_if_not_exists()
    RETURNS trigger AS $$
    DECLARE
      partition_name TEXT;
      start_date DATE;
      end_date DATE;
    BEGIN
      start_date := DATE_TRUNC('month', NEW.killmail_time);
      end_date := start_date + INTERVAL '1 month';
      partition_name := 'killmails_raw_y' || TO_CHAR(NEW.killmail_time, 'YYYY') || 'm' || TO_CHAR(NEW.killmail_time, 'MM');
      
      IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE tablename = partition_name
      ) THEN
        EXECUTE format(
          'CREATE TABLE %I PARTITION OF killmails_raw_partitioned FOR VALUES FROM (%L) TO (%L)',
          partition_name, start_date, end_date
        );
        
        -- Create indexes on the new partition
        EXECUTE format('CREATE INDEX %I ON %I (solar_system_id, killmail_time)', partition_name || '_system_time_idx', partition_name);
        EXECUTE format('CREATE INDEX %I ON %I (victim_character_id, killmail_time)', partition_name || '_victim_time_idx', partition_name);
      END IF;
      
      RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;
    """, """
    DROP FUNCTION IF EXISTS create_monthly_partition_if_not_exists();
    """
    
    # =====================================
    # Materialized Views for Analytics
    # =====================================
    
    # Character activity summary
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS character_activity_summary AS
    SELECT 
      p.character_id,
      p.character_name,
      COUNT(*) FILTER (WHERE p.is_victim = false) as total_kills,
      COUNT(*) FILTER (WHERE p.is_victim = true) as total_losses,
      SUM(k.total_value) FILTER (WHERE p.is_victim = false) as total_isk_destroyed,
      SUM(k.total_value) FILTER (WHERE p.is_victim = true) as total_isk_lost,
      MAX(k.killmail_time) as last_activity,
      COUNT(DISTINCT k.solar_system_id) as unique_systems,
      COUNT(DISTINCT p.ship_type_id) as unique_ships_flown,
      AVG(k.total_value) as avg_kill_value
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    GROUP BY p.character_id, p.character_name;
    
    CREATE UNIQUE INDEX ON character_activity_summary (character_id);
    CREATE INDEX ON character_activity_summary (total_kills DESC);
    CREATE INDEX ON character_activity_summary (total_isk_destroyed DESC);
    CREATE INDEX ON character_activity_summary (last_activity DESC);
    """, """
    DROP MATERIALIZED VIEW IF EXISTS character_activity_summary;
    """
    
    # Recent character activity (24h)
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS recent_character_activity AS
    SELECT 
      p.character_id,
      p.character_name,
      COUNT(*) FILTER (WHERE p.is_victim = false) as kills_24h,
      COUNT(*) FILTER (WHERE p.is_victim = true) as losses_24h,
      SUM(k.total_value) as isk_involved_24h,
      jsonb_agg(DISTINCT jsonb_build_object(
        'system_id', k.solar_system_id,
        'ship_type_id', p.ship_type_id,
        'time', k.killmail_time
      ) ORDER BY k.killmail_time DESC) as recent_activity
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE k.killmail_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    GROUP BY p.character_id, p.character_name;
    
    CREATE UNIQUE INDEX ON recent_character_activity (character_id);
    CREATE INDEX ON recent_character_activity (kills_24h DESC);
    """, """
    DROP MATERIALIZED VIEW IF EXISTS recent_character_activity;
    """
    
    # System activity heatmap
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS system_activity_heatmap AS
    SELECT 
      solar_system_id,
      DATE_TRUNC('hour', killmail_time) as hour,
      COUNT(*) as kill_count,
      SUM(total_value) as total_isk_destroyed,
      COUNT(DISTINCT victim_character_id) as unique_victims,
      COUNT(DISTINCT victim_corporation_id) as unique_corporations,
      AVG(attacker_count) as avg_attacker_count
    FROM killmails_raw
    WHERE killmail_time >= CURRENT_TIMESTAMP - INTERVAL '7 days'
    GROUP BY solar_system_id, DATE_TRUNC('hour', killmail_time);
    
    CREATE INDEX ON system_activity_heatmap (solar_system_id, hour DESC);
    CREATE INDEX ON system_activity_heatmap (kill_count DESC);
    """, """
    DROP MATERIALIZED VIEW IF EXISTS system_activity_heatmap;
    """
    
    # Corporation member activity
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS corporation_member_activity AS
    SELECT 
      p.corporation_id,
      p.corporation_name,
      COUNT(DISTINCT p.character_id) as active_members,
      COUNT(*) as total_kills,
      SUM(k.total_value) as total_isk_destroyed,
      jsonb_object_agg(
        p.character_id::text,
        jsonb_build_object(
          'name', p.character_name,
          'kills', COUNT(*) FILTER (WHERE p.is_victim = false),
          'losses', COUNT(*) FILTER (WHERE p.is_victim = true)
        )
      ) as member_stats
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    WHERE k.killmail_time >= CURRENT_TIMESTAMP - INTERVAL '30 days'
      AND p.is_victim = false
    GROUP BY p.corporation_id, p.corporation_name;
    
    CREATE UNIQUE INDEX ON corporation_member_activity (corporation_id);
    CREATE INDEX ON corporation_member_activity (active_members DESC);
    """, """
    DROP MATERIALIZED VIEW IF EXISTS corporation_member_activity;
    """
    
    # Ship type effectiveness
    execute """
    CREATE MATERIALIZED VIEW IF NOT EXISTS ship_type_effectiveness AS
    SELECT 
      p.ship_type_id,
      it.type_name as ship_name,
      COUNT(*) FILTER (WHERE p.is_victim = false) as kills_with,
      COUNT(*) FILTER (WHERE p.is_victim = true) as losses_with,
      AVG(k.total_value) FILTER (WHERE p.is_victim = false) as avg_kill_value,
      AVG(k.total_value) FILTER (WHERE p.is_victim = true) as avg_loss_value,
      COUNT(DISTINCT p.character_id) as unique_pilots,
      CASE 
        WHEN COUNT(*) FILTER (WHERE p.is_victim = true) = 0 THEN 100.0
        ELSE ROUND(
          COUNT(*) FILTER (WHERE p.is_victim = false)::numeric * 100.0 / 
          COUNT(*)::numeric, 2
        )
      END as effectiveness_ratio
    FROM participants p
    JOIN killmails_raw k ON p.killmail_id = k.killmail_id
    LEFT JOIN eve_item_types it ON p.ship_type_id = it.type_id
    GROUP BY p.ship_type_id, it.type_name
    HAVING COUNT(*) > 10;
    
    CREATE UNIQUE INDEX ON ship_type_effectiveness (ship_type_id);
    CREATE INDEX ON ship_type_effectiveness (effectiveness_ratio DESC);
    """, """
    DROP MATERIALIZED VIEW IF EXISTS ship_type_effectiveness;
    """
    
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
    );
    """, """
    DROP TABLE IF EXISTS view_refresh_tracking;
    """
    
    # =====================================
    # Helper Functions
    # =====================================
    
    # Function to calculate threat score
    execute """
    CREATE OR REPLACE FUNCTION calculate_threat_score(
      kill_count INTEGER,
      solo_kills INTEGER,
      avg_victim_count INTEGER,
      days_active INTEGER
    ) RETURNS NUMERIC AS $$
    BEGIN
      RETURN ROUND(
        (kill_count * 0.3 + 
         solo_kills * 0.4 + 
         avg_victim_count * 0.2 + 
         days_active * 0.1) / 10.0, 2
      );
    END;
    $$ LANGUAGE plpgsql IMMUTABLE;
    """, """
    DROP FUNCTION IF EXISTS calculate_threat_score(INTEGER, INTEGER, INTEGER, INTEGER);
    """
    
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
    """, """
    DROP FUNCTION IF EXISTS classify_engagement(INTEGER);
    """
  end
  
  def down do
    # Drop functions
    execute "DROP FUNCTION IF EXISTS classify_engagement(INTEGER);"
    execute "DROP FUNCTION IF EXISTS calculate_threat_score(INTEGER, INTEGER, INTEGER, INTEGER);"
    
    # Drop tracking table
    execute "DROP TABLE IF EXISTS view_refresh_tracking;"
    
    # Drop materialized views
    execute "DROP MATERIALIZED VIEW IF EXISTS ship_type_effectiveness;"
    execute "DROP MATERIALIZED VIEW IF EXISTS corporation_member_activity;"
    execute "DROP MATERIALIZED VIEW IF EXISTS system_activity_heatmap;"
    execute "DROP MATERIALIZED VIEW IF EXISTS recent_character_activity;"
    execute "DROP MATERIALIZED VIEW IF EXISTS character_activity_summary;"
    
    # Drop partitioning function
    execute "DROP FUNCTION IF EXISTS create_monthly_partition_if_not_exists();"
    
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
      """, ""
      
      # Create indexes on the partition
      execute """
      CREATE INDEX IF NOT EXISTS #{partition_name}_system_time_idx 
      ON #{partition_name} (solar_system_id, killmail_time);
      """, ""
      
      execute """
      CREATE INDEX IF NOT EXISTS #{partition_name}_victim_time_idx 
      ON #{partition_name} (victim_character_id, killmail_time);
      """, ""
    end)
  end
end