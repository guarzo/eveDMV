defmodule EveDmv.Repo.Migrations.AddComprehensiveIntelligenceIndexesSprint16 do
  use Ecto.Migration
  @disable_ddl_transaction true

  # Configurable threshold values for index WHERE clauses
  # MAINTENANCE NOTE: These values should be reviewed quarterly and adjusted based on:
  # - Data growth patterns and retention policies
  # - Query performance metrics
  # - Storage constraints and index maintenance costs
  @min_isk_threshold_millions 100  # 100M ISK minimum for high-value analysis (review quarterly)
  @intelligence_data_cutoff "2024-01-01"  # Minimum date for intelligence data (adjust as data ages)
  @recent_activity_cutoff "2024-06-01"    # Recent activity analysis cutoff (update with data retention)

  def up do
    # Use regular indexes for test environment, concurrent for others
    concurrently = if Mix.env() == :test, do: "", else: "CONCURRENTLY"
    
    # Calculate dynamic thresholds
    isk_threshold = @min_isk_threshold_millions * 1_000_000  # Convert to actual ISK value
    
    # ====================================================================
    # INTELLIGENCE QUERY PATTERN INDEXES
    # ====================================================================
    # These indexes are optimized for Sprint 16 intelligence system queries.
    # Threshold values are configurable at the top of this file and should be
    # reviewed quarterly for optimal performance.
    
    # 1. BATTLE ANALYSIS INTEGRATION INDEXES
    # -------------------------------------
    
    # Index for battle detection time range queries with system filtering
    # Optimizes: battle detection service queries for specific systems and time ranges
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_system_time_battle_analysis
    ON killmails_raw (solar_system_id, killmail_time DESC)
    WHERE killmail_time >= '#{@intelligence_data_cutoff}'::timestamp
    """

    # Index for ISK destruction analysis in battle intelligence 
    # Supports battle threat detection based on ISK values and participant counts
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_isk_participants_threat
    ON killmails_raw (killmail_time DESC, solar_system_id)
    WHERE raw_data ? 'zkb' AND (raw_data->'zkb'->>'totalValue')::bigint > #{isk_threshold}
    """

    # 2. VETTING ANALYSIS PERFORMANCE INDEXES  
    # ----------------------------------------
    
    # Index for vetting analysis timestamp queries
    # Optimizes: get_recent_vetting_analyses() timeframe filtering
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_wh_vetting_analysis_timestamp
    ON wh_vetting (last_updated_at DESC, overall_risk_score)
    WHERE status = 'complete'
    """

    # Index for character-based vetting lookups in intelligence dashboard
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_wh_vetting_character_recent
    ON wh_vetting (character_id, last_updated_at DESC)
    WHERE status IN ('complete', 'pending')
    """

    # 3. THREAT SCORING OPTIMIZATION INDEXES
    # --------------------------------------
    
    # Composite index for character threat analysis with time filtering
    # Optimizes: character intelligence dashboard threat assessment queries  
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_char_threat_analysis
    ON killmails_raw (victim_character_id, killmail_time DESC, solar_system_id)
    WHERE victim_character_id IS NOT NULL AND killmail_time >= '2024-01-01'::timestamp
    """

    # Index for attacker-based threat correlation in multi-character analysis
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_attackers_threat_scoring
    ON killmails_raw USING GIN ((raw_data -> 'attackers'))
    WHERE killmail_time >= '#{@intelligence_data_cutoff}'::timestamp
    """

    # 4. SYSTEM ACTIVITY MONITORING INDEXES
    # -------------------------------------
    
    # Index for system activity volume analysis
    # Supports: check_killmail_volume_anomaly() and system threat detection
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_system_activity_volume
    ON killmails_raw (solar_system_id, killmail_time DESC)
    WHERE killmail_time >= '#{@recent_activity_cutoff}'::timestamp
    """

    # Index for large battle detection (participant count analysis)
    # Simplified condition to avoid potential non-immutable functions
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_large_battles
    ON killmails_raw (killmail_time DESC, solar_system_id)
    WHERE (raw_data->'attackers') IS NOT NULL 
    AND killmail_time >= '#{@intelligence_data_cutoff}'::timestamp
    """

    # 5. MULTI-SYSTEM BATTLE CORRELATION INDEXES
    # ------------------------------------------
    
    # Index for temporal clustering in multi-system battle correlation
    # Optimizes: MultiSystemBattleCorrelator temporal analysis
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_temporal_clustering
    ON killmails_raw (killmail_time, solar_system_id, victim_character_id)
    WHERE killmail_time >= '#{@intelligence_data_cutoff}'::timestamp
    """

    # Index for participant overlap analysis across systems
    # Note: Attackers GIN index already exists as idx_killmails_attackers_threat_scoring
    # Only need victim data index for participant analysis
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_victim_gin
    ON killmails_raw USING GIN ((raw_data->'victim'))
    WHERE killmail_time >= '#{@intelligence_data_cutoff}'::timestamp
    """

    # 6. CACHE OPTIMIZATION INDEXES
    # -----------------------------
    
    # Index for intelligence cache warming queries
    # Supports: warm_intelligence_cache() character data preloading
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_cache_warming
    ON killmails_raw (victim_character_id, killmail_time DESC)
    WHERE victim_character_id IS NOT NULL 
    AND killmail_time >= '#{@intelligence_data_cutoff}'::timestamp
    """

    # 7. DASHBOARD QUERY OPTIMIZATION INDEXES
    # ---------------------------------------
    
    # Index for recent activity analysis in intelligence dashboard
    # Using fixed timestamp instead of NOW() since NOW() is not immutable
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_dashboard_recent
    ON killmails_raw (killmail_time DESC, victim_character_id, solar_system_id)
    WHERE killmail_time >= '#{@intelligence_data_cutoff}'::timestamp
    """

    # Index for threat alert generation queries
    # Simplified condition to avoid non-immutable functions
    execute """
    CREATE INDEX #{concurrently} IF NOT EXISTS idx_killmails_threat_alerts
    ON killmails_raw (killmail_time DESC, solar_system_id)
    WHERE (raw_data->'zkb'->>'totalValue')::bigint > 500000000
    AND killmail_time >= '#{@intelligence_data_cutoff}'::timestamp
    """
  end

  def down do
    # Use regular drop for test environment, concurrent for others  
    concurrently = if Mix.env() == :test, do: "", else: "CONCURRENTLY"
    
    # Drop all the intelligence indexes
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_system_time_battle_analysis"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_isk_participants_threat"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_wh_vetting_analysis_timestamp"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_wh_vetting_character_recent"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_char_threat_analysis"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_attackers_threat_scoring"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_system_activity_volume"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_large_battles"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_temporal_clustering"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_victim_gin"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_cache_warming"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_dashboard_recent"
    execute "DROP INDEX #{concurrently} IF EXISTS idx_killmails_threat_alerts"
  end
end