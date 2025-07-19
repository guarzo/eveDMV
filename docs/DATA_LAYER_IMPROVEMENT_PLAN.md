# EVE DMV Data Layer Improvement Implementation Plan

## Executive Summary

This document outlines a comprehensive implementation plan to address the data layer improvements identified in the Ash Framework, migrations, and performance review. The plan is organized into sprints with clear priorities, dependencies, and success metrics.

## Priority Matrix

| Priority | Impact | Effort | Items |
|----------|--------|--------|-------|
| **Critical** | High | Medium | Table Partitioning, Missing Critical Indexes |
| **High** | High | Low | Query Safety Limits, Index Consolidation |
| **Medium** | Medium | Medium | Resource Reorganization, Materialized View Optimization |
| **Low** | Low | Low | Documentation, Monitoring Enhancements |

---

## Sprint 1: Critical Performance Foundation (1 week)

### Goals
- Implement table partitioning for time-series data
- Add missing critical performance indexes
- Ensure zero downtime during implementation

### Tasks

#### 1.1 Table Partitioning Implementation

**File**: `priv/repo/migrations/[timestamp]_implement_killmail_partitioning.exs`

```elixir
defmodule EveDmv.Repo.Migrations.ImplementKillmailPartitioning do
  use Ecto.Migration
  
  def up do
    # Create partitioned table structure
    execute """
    -- Rename existing table
    ALTER TABLE killmails_raw RENAME TO killmails_raw_old;
    
    -- Create new partitioned table
    CREATE TABLE killmails_raw (
      LIKE killmails_raw_old INCLUDING ALL
    ) PARTITION BY RANGE (killmail_time);
    
    -- Create partitions for recent months
    CREATE TABLE killmails_raw_2024_01 PARTITION OF killmails_raw
      FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
    
    CREATE TABLE killmails_raw_2024_02 PARTITION OF killmails_raw
      FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
    
    -- Continue for all needed months...
    """
    
    # Migrate data in batches
    execute """
    INSERT INTO killmails_raw 
    SELECT * FROM killmails_raw_old 
    WHERE killmail_time >= '2024-01-01'
    ON CONFLICT DO NOTHING;
    """
  end
  
  def down do
    # Reversal strategy
    execute "DROP TABLE killmails_raw CASCADE"
    execute "ALTER TABLE killmails_raw_old RENAME TO killmails_raw"
  end
end
```

**Script**: `scripts/partition_migration_helper.sh`
```bash
#!/bin/bash
# Helper script for safe partition migration

# 1. Create new partitions ahead of time
psql $DATABASE_URL <<SQL
CREATE TABLE killmails_raw_2024_03 PARTITION OF killmails_raw
  FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
SQL

# 2. Monitor migration progress
watch -n 5 'psql $DATABASE_URL -c "SELECT COUNT(*) FROM killmails_raw"'
```

#### 1.2 Add Missing Critical Indexes

**File**: `priv/repo/migrations/[timestamp]_add_missing_critical_indexes.exs`

```elixir
defmodule EveDmv.Repo.Migrations.AddMissingCriticalIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true
  
  def change do
    # Ship type analysis index
    create_if_not_exists index(:participants, [:ship_type_id, :killmail_time], 
      name: :idx_participants_ship_type_analysis,
      concurrently: true,
      comment: "Optimizes ship type analysis queries")
    
    # Weapon type analysis index  
    create_if_not_exists index(:participants, [:weapon_type_id], 
      name: :idx_participants_weapon_type,
      where: "weapon_type_id IS NOT NULL",
      concurrently: true,
      comment: "Speeds up weapon analysis queries")
    
    # Surveillance profile filter tree GIN index
    create_if_not_exists index(:surveillance_profiles, [:filter_tree], 
      name: :idx_surveillance_profiles_filter_gin,
      using: :gin,
      concurrently: true,
      comment: "Enables fast JSONB filter searches")
    
    # ZKB value queries expression index
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_killmails_zkb_value
    ON killmails_raw ((raw_data->'zkb'->>'totalValue')::bigint DESC)
    WHERE raw_data ? 'zkb'
    """
    
    # Covering index for character analysis
    execute """
    CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_killmails_character_covering
    ON killmails_raw (victim_character_id, killmail_time DESC)
    INCLUDE (solar_system_id, victim_ship_type_id, total_value)
    WHERE killmail_time >= '2024-01-01'
    """
  end
end
```

#### 1.3 Partition Automation Setup

**File**: `lib/eve_dmv/database/partition_manager.ex`

```elixir
defmodule EveDmv.Database.PartitionManager do
  @moduledoc """
  Automated partition management for time-series tables
  """
  use GenServer
  require Logger
  
  @check_interval :timer.hours(24)
  @months_ahead 3
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end
  
  def handle_info(:check_partitions, state) do
    create_future_partitions()
    drop_old_partitions()
    schedule_check()
    {:noreply, state}
  end
  
  defp create_future_partitions do
    # Create partitions for the next 3 months
    Enum.each(0..@months_ahead, fn months_offset ->
      date = Date.utc_today() |> Date.add(months_offset * 30)
      create_partition_for_month(date)
    end)
  end
  
  defp create_partition_for_month(date) do
    partition_name = "killmails_raw_#{date.year}_#{String.pad_leading("#{date.month}", 2, "0")}"
    start_date = Date.beginning_of_month(date)
    end_date = Date.add(start_date, Date.days_in_month(date))
    
    sql = """
    CREATE TABLE IF NOT EXISTS #{partition_name} 
    PARTITION OF killmails_raw
    FOR VALUES FROM ('#{start_date}') TO ('#{end_date}')
    """
    
    case Ecto.Adapters.SQL.query(EveDmv.Repo, sql) do
      {:ok, _} -> Logger.info("Created partition #{partition_name}")
      {:error, error} -> Logger.error("Failed to create partition: #{inspect(error)}")
    end
  end
  
  defp schedule_check do
    Process.send_after(self(), :check_partitions, @check_interval)
  end
end
```

### Success Metrics
- [ ] All killmails_raw data successfully migrated to partitioned table
- [ ] Query performance improvement of 10x+ for time-based queries
- [ ] All missing indexes created without blocking operations
- [ ] Zero downtime during migration

---

## Sprint 2: Query Safety and Optimization (3 days)

### Goals
- Add query limits to prevent runaway queries
- Consolidate redundant indexes
- Implement query timeout protection

### Tasks

#### 2.1 Query Safety Limits

**File**: `lib/eve_dmv/database/query_helpers.ex`

```elixir
defmodule EveDmv.Database.QueryHelpers do
  @moduledoc """
  Query safety helpers and limits
  """
  
  import Ecto.Query
  
  @default_limit 1000
  @max_limit 10_000
  
  @doc """
  Apply safe limits to queries
  """
  def apply_safe_limit(query, opts \\ []) do
    requested_limit = Keyword.get(opts, :limit, @default_limit)
    safe_limit = min(requested_limit, @max_limit)
    
    query
    |> limit(^safe_limit)
  end
  
  @doc """
  Apply query timeout
  """
  def with_timeout(query, timeout_ms \\ 30_000) do
    # Set statement timeout for this query
    repo_opts = [timeout: timeout_ms]
    {query, repo_opts}
  end
end
```

**Update Ash Resources** - Add to all read actions:

```elixir
# In each resource file
read :list do
  prepare fn query, _ ->
    query
    |> EveDmv.Database.QueryHelpers.apply_safe_limit()
  end
end
```

#### 2.2 Index Consolidation

**File**: `priv/repo/migrations/[timestamp]_consolidate_redundant_indexes.exs`

```elixir
defmodule EveDmv.Repo.Migrations.ConsolidateRedundantIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true
  
  def up do
    # Drop redundant indexes (covered by other indexes)
    drop_if_exists index(:killmails_raw, [:victim_character_id, :killmail_time], 
      name: :killmails_raw_victim_time_idx)
    
    # Create optimized composite index to replace multiple single indexes
    create_if_not_exists index(:participants, 
      [:character_id, :corporation_id, :alliance_id, :killmail_time],
      name: :idx_participants_affiliation_composite,
      concurrently: true,
      comment: "Replaces multiple affiliation indexes")
  end
  
  def down do
    # Restore original indexes if needed
  end
end
```

### Success Metrics
- [ ] All queries have appropriate limits
- [ ] Query timeout protection in place
- [ ] Index count reduced by 10-20% without performance impact
- [ ] No unbounded queries in production

---

## Sprint 3: Resource Organization and Architecture (1 week)

### Goals
- Reorganize Ash resources into proper domains
- Fix cross-domain relationships
- Improve API structure

### Tasks

#### 3.1 Resource Domain Reorganization

**Move battle-related resources to dedicated domain:**

```elixir
# Create new domain
defmodule EveDmv.Api.BattleAnalysis do
  use Ash.Domain
  
  resources do
    resource EveDmv.BattleAnalysis.Battle
    resource EveDmv.BattleAnalysis.BattleKillmail
    resource EveDmv.BattleAnalysis.CombatLog
    resource EveDmv.BattleAnalysis.ShipFitting
    resource EveDmv.BattleAnalysis.BattleMetrics
  end
end
```

**Update resource files:**
```elixir
# Move from EveDmv.Killmails.Battle to:
defmodule EveDmv.BattleAnalysis.Battle do
  use Ash.Resource,
    domain: EveDmv.Api.BattleAnalysis,
    data_layer: AshPostgres.DataLayer
    
  # Update relationships to use proper domain references
end
```

#### 3.2 Add Missing Resource Relationships

```elixir
# In Participant resource
relationships do
  belongs_to :ship_type, EveDmv.Eve.ItemType do
    source_attribute :ship_type_id
    destination_attribute :type_id
  end
  
  belongs_to :weapon_type, EveDmv.Eve.ItemType do
    source_attribute :weapon_type_id
    destination_attribute :type_id
  end
end
```

### Success Metrics
- [ ] All resources in appropriate domains
- [ ] No circular dependencies between domains
- [ ] Clean API structure with clear boundaries
- [ ] All relationships properly defined

---

## Sprint 4: Materialized View Optimization (3 days)

### Goals
- Implement incremental refresh strategy
- Add more granular materialized views
- Optimize refresh performance

### Tasks

#### 4.1 Incremental Refresh Implementation

**File**: `lib/eve_dmv/database/incremental_view_refresher.ex`

```elixir
defmodule EveDmv.Database.IncrementalViewRefresher do
  @moduledoc """
  Incremental materialized view refresh strategy
  """
  
  def refresh_character_activity_summary do
    # Track last refresh timestamp
    last_refresh = get_last_refresh_time("character_activity_summary")
    
    # Only refresh data that changed
    sql = """
    -- Insert new/updated records into temp table
    CREATE TEMP TABLE character_activity_delta AS
    SELECT * FROM generate_character_activity_data()
    WHERE last_activity > $1;
    
    -- Merge delta into materialized view
    INSERT INTO character_activity_summary
    SELECT * FROM character_activity_delta
    ON CONFLICT (character_id) DO UPDATE SET
      total_kills = EXCLUDED.total_kills,
      total_losses = EXCLUDED.total_losses,
      last_activity = EXCLUDED.last_activity;
    """
    
    Ecto.Adapters.SQL.query!(EveDmv.Repo, sql, [last_refresh])
    update_refresh_time("character_activity_summary")
  end
end
```

#### 4.2 Add Granular Views

**File**: `priv/repo/migrations/[timestamp]_add_granular_materialized_views.exs`

```elixir
defmodule EveDmv.Repo.Migrations.AddGranularMaterializedViews do
  use Ecto.Migration
  
  def up do
    # Recent activity view (smaller, refreshes more frequently)
    execute """
    CREATE MATERIALIZED VIEW recent_character_activity AS
    SELECT 
      character_id,
      character_name,
      COUNT(*) FILTER (WHERE is_victim = false) as kills_24h,
      COUNT(*) FILTER (WHERE is_victim = true) as losses_24h,
      SUM(total_value) as isk_involved_24h
    FROM killmails_with_participants
    WHERE killmail_time >= NOW() - INTERVAL '24 hours'
    GROUP BY character_id, character_name;
    
    CREATE INDEX ON recent_character_activity (character_id);
    """
    
    # System activity heatmap
    execute """
    CREATE MATERIALIZED VIEW system_activity_heatmap AS
    SELECT
      solar_system_id,
      DATE_TRUNC('hour', killmail_time) as hour,
      COUNT(*) as kill_count,
      SUM(total_value) as total_isk_destroyed,
      COUNT(DISTINCT victim_character_id) as unique_victims
    FROM killmails_raw
    WHERE killmail_time >= NOW() - INTERVAL '7 days'
    GROUP BY solar_system_id, DATE_TRUNC('hour', killmail_time);
    
    CREATE INDEX ON system_activity_heatmap (solar_system_id, hour DESC);
    """
  end
  
  def down do
    execute "DROP MATERIALIZED VIEW IF EXISTS recent_character_activity"
    execute "DROP MATERIALIZED VIEW IF EXISTS system_activity_heatmap"
  end
end
```

### Success Metrics
- [ ] Incremental refresh reduces refresh time by 80%+
- [ ] New granular views provide real-time data (< 5 min lag)
- [ ] Overall system load reduced during refresh cycles
- [ ] Query performance improved for common dashboard queries

---

## Sprint 5: Advanced Performance Features (1 week)

### Goals
- Implement distributed caching
- Add query result streaming
- Set up performance regression tests

### Tasks

#### 5.1 Distributed Cache Implementation

**Add to mix.exs:**
```elixir
{:nebulex, "~> 2.5"},
{:nebulex_redis_adapter, "~> 2.3"}
```

**File**: `lib/eve_dmv/cache/distributed_cache.ex`

```elixir
defmodule EveDmv.Cache.Distributed do
  use Nebulex.Cache,
    otp_app: :eve_dmv,
    adapter: Nebulex.Adapters.Redis
    
  @ttl :timer.minutes(15)
  
  def get_or_compute(key, ttl \\ @ttl, fun) do
    case get(key) do
      nil ->
        value = fun.()
        put(key, value, ttl: ttl)
        value
      value ->
        value
    end
  end
end
```

#### 5.2 Query Result Streaming

**File**: `lib/eve_dmv/database/streaming.ex`

```elixir
defmodule EveDmv.Database.Streaming do
  @moduledoc """
  Streaming query support for large datasets
  """
  
  def stream_query(query, batch_size \\ 1000) do
    Stream.resource(
      fn -> {query, 0} end,
      fn {query, offset} ->
        batch = query
        |> limit(^batch_size)
        |> offset(^offset)
        |> Repo.all()
        
        case batch do
          [] -> {:halt, {query, offset}}
          items -> {items, {query, offset + batch_size}}
        end
      end,
      fn _ -> :ok end
    )
  end
end
```

#### 5.3 Performance Regression Tests

**File**: `test/performance/regression_test.exs`

```elixir
defmodule EveDmv.PerformanceRegressionTest do
  use EveDmv.DataCase
  
  @baseline_queries %{
    character_activity: 100,  # ms
    battle_detection: 500,    # ms
    surveillance_match: 200   # ms
  }
  
  describe "query performance regression" do
    test "character activity query stays within baseline" do
      {time, _result} = :timer.tc(fn ->
        CharacterQueries.get_character_activity(123, days: 30)
      end)
      
      time_ms = time / 1000
      baseline = @baseline_queries[:character_activity]
      
      assert time_ms < baseline * 1.5, 
        "Query took #{time_ms}ms, baseline is #{baseline}ms"
    end
  end
end
```

### Success Metrics
- [ ] Distributed cache reduces database load by 50%+
- [ ] Large query results can be streamed without memory issues
- [ ] Performance regression tests catch slowdowns before production
- [ ] 95th percentile query time < 100ms

---

## Implementation Timeline

| Week | Sprint | Focus Area | Risk Level |
|------|--------|------------|------------|
| 1 | Sprint 1 | Critical Performance (Partitioning) | High |
| 1.5 | Sprint 2 | Query Safety | Low |
| 2-3 | Sprint 3 | Resource Organization | Medium |
| 3.5 | Sprint 4 | View Optimization | Low |
| 4-5 | Sprint 5 | Advanced Features | Medium |

## Risk Mitigation

### High-Risk Operations
1. **Table Partitioning Migration**
   - Run in maintenance window
   - Have rollback script ready
   - Test on staging environment first
   - Monitor closely for 24 hours post-migration

2. **Resource Reorganization**
   - Update one domain at a time
   - Maintain backwards compatibility
   - Run comprehensive test suite after each change

### Rollback Procedures
Each migration should include:
- Documented rollback steps
- Data preservation strategy
- Communication plan for issues

## Monitoring and Validation

### Key Metrics to Track
1. **Query Performance**
   - 95th percentile response time
   - Slow query count
   - Cache hit rate

2. **Database Health**
   - Connection pool utilization
   - Index usage statistics
   - Table bloat metrics

3. **Application Performance**
   - Request response times
   - Memory usage trends
   - Background job performance

### Success Criteria
- [ ] 10x improvement in time-based query performance
- [ ] 50% reduction in database load
- [ ] Zero critical performance regressions
- [ ] All queries complete in < 1 second

## Long-term Roadmap

### Phase 2 (Months 2-3)
- Implement read replicas for analytics
- Add time-series specific optimizations
- Implement data archival strategy

### Phase 3 (Months 4-6)
- Machine learning for query optimization
- Predictive cache warming
- Advanced monitoring dashboards

## Conclusion

This implementation plan provides a structured approach to improving the EVE DMV data layer. By following this plan, we can achieve significant performance improvements while maintaining system stability and data integrity.

The phased approach allows for incremental improvements with measurable success metrics at each stage. Regular monitoring and rollback procedures ensure safe implementation of even the most complex changes.